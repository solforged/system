import { afterEach, beforeEach, expect, test } from "bun:test";
import type { ExtensionAPI, ProviderConfig } from "@oh-my-pi/pi-coding-agent";
import register from "../config/omp/extensions/nous-portal";

const now = 1_800_000_000_000;
let provider: ProviderConfig;
register({ registerProvider: (_name, config) => { provider = config; } } as ExtensionAPI);
const oauth = provider!.oauth!;
const realFetch = globalThis.fetch;
const realNow = Date.now;
beforeEach(() => { Date.now = () => now; });

afterEach(() => {
  globalThis.fetch = realFetch;
  Date.now = realNow;
});

function jwt(claims: Record<string, unknown> = {}): string {
  return `e30.${Buffer.from(JSON.stringify({
    sub: "test-account", scope: "inference:invoke", exp: now / 1000 + 3600, ...claims,
  })).toString("base64url")}.test-signature`;
}
const device = {
  device_code: "test-device-code", user_code: "ABCD-EFGH",
  verification_uri_complete: "https://portal.nousresearch.com/device?user_code=ABCD-EFGH",
  expires_in: 600, interval: 1,
};

test("device authorization handles pending and slow_down before returning credentials", async () => {
  let polls = 0;
  let shown = false;
  globalThis.fetch = (async (url, init) => {
    const form = new URLSearchParams(init!.body as string);
    if (String(url).endsWith("/device/code")) {
      expect(form.get("scope")).toBe("inference:invoke");
      return Response.json(device);
    }
    expect(shown).toBe(true);
    expect(form.get("grant_type")).toBe("urn:ietf:params:oauth:grant-type:device_code");
    if (++polls === 1) return Response.json({ error: "authorization_pending" }, { status: 400 });
    if (polls === 2) return Response.json({ error: "slow_down" }, { status: 400 });
    return Response.json({ access_token: jwt(), refresh_token: "new-grant" });
  }) as typeof fetch;
  const result = await oauth.login({ onAuth: () => { shown = true; }, onPrompt: async () => "" });
  expect(typeof result).not.toBe("string");
  expect((result as Exclude<typeof result, string>).expires).toBe(now + 3_600_000 - 120_000);
}, 15_000);

test("refresh rotates the grant and uses the inference JWT's expiry", async () => {
  globalThis.fetch = (async (_url, init) => {
    const form = new URLSearchParams(init!.body as string);
    expect(new Headers(init!.headers).get("x-nous-refresh-token")).toBe("old-grant");
    expect(form.has("refresh_token")).toBe(false);
    expect(form.get("grant_type")).toBe("refresh_token");
    return Response.json({ access_token: jwt({ exp: now / 1000 + 900 }), refresh_token: "rotated-grant", expires_in: 86400 });
  }) as typeof fetch;
  const result = await oauth.refreshToken!({ access: jwt(), refresh: "old-grant", expires: now - 1, orgId: "existing-org" });
  expect(result.refresh).toBe("rotated-grant");
  expect(result.expires).toBe(now + 900_000 - 120_000);
  expect(result.orgId).toBe("existing-org");
});

for (const [name, token] of [
  ["opaque OAuth token", () => "not-an-inference-jwt"],
  ["missing inference scope", () => jwt({ scope: "profile" })],
  ["expiry at the refresh boundary", () => jwt({ exp: now / 1000 + 120 })],
] as const) {
  test(`rejects ${name} before it can be used for inference`, async () => {
    globalThis.fetch = (async () => Response.json({ access_token: token(), refresh_token: "rotated-grant" })) as typeof fetch;
    await expect(oauth.refreshToken!({ access: jwt(), refresh: "old-grant", expires: now - 1 })).rejects.toThrow("Nous Portal");
  });
}

test("cancelling authorization stops before polling or saving a grant", async () => {
  const controller = new AbortController();
  let requests = 0;
  globalThis.fetch = (async () => { requests++; return Response.json(device); }) as typeof fetch;
  await expect(oauth.login({
    signal: controller.signal, onAuth: () => controller.abort(), onPrompt: async () => "",
  })).rejects.toThrow();
  expect(requests).toBe(1);
});

test("a gateway challenge is not reported as a revoked grant", async () => {
  globalThis.fetch = (async () => new Response("edge security checkpoint", {
    status: 403, headers: { "x-vercel-mitigated": "challenge" },
  })) as typeof fetch;
  await expect(oauth.refreshToken!({ access: jwt(), refresh: "old-grant", expires: now - 1 })).rejects.toThrow("HTTP 403");
});

test("catalog discovery separates chat from embeddings and preserves capabilities", async () => {
  globalThis.fetch = (async () => Response.json({ data: [
    {
      id: "vendor/reasoner", name: "Reasoner", context_length: 200_000,
      architecture: { input_modalities: ["text", "image"], output_modalities: ["text"] },
      top_provider: { max_completion_tokens: 32_768 },
      supported_parameters: ["tools", "reasoning"],
      pricing: { prompt: "0.000002", completion: "0.000008" },
    },
    {
      id: "vendor/embed", name: "Embeddings", context_length: 8192,
      architecture: { input_modalities: ["text"], output_modalities: ["embeddings"] },
    },
  ] })) as typeof fetch;
  const models = await provider.fetchDynamicModels!(undefined);
  expect(models.map(model => model.id)).toEqual(["vendor/reasoner"]);
  expect(models[0]).toMatchObject({
    reasoning: true, supportsTools: true, input: ["text", "image"],
    contextWindow: 200_000, maxTokens: 32_768, cost: { input: 2, output: 8 },
  });
});

test("usage distinguishes subscription windows, model tiers, and credit balances", async () => {
  const report = await provider.usage!.fetchUsage({
    provider: "nous", credential: { type: "oauth", accessToken: jwt(), accountId: "test-account" },
  }, { fetch: (async () => Response.json({
    usage_window: { gauges: [
      { id: "day", scope: "all", label: "Daily", used_bp: 3750, resets_at_ms: now + 60_000 },
      { id: "top_tier", scope: "top_tier", label: "Large models", used_bp: 10_000 },
      { id: "unrecognized", scope: "new-scope", used_bp: 5000 },
      { id: "bad-percentage", scope: "all", used_bp: 10_001 },
    ] },
    paid_service_access: { total_usable_credits: 0 },
  })) as typeof fetch });
  expect(report!.limits.map(limit => limit.id)).toEqual(["day", "top_tier"]);
  expect(report!.limits[0]).toMatchObject({
    amount: { used: 37.5, limit: 100, usedFraction: 0.375, unit: "percent" },
    window: { resetsAt: now + 60_000 }, status: "ok",
  });
  expect(report!.limits[1]).toMatchObject({ scope: { tier: "top_tier" }, status: "exhausted" });
  expect(report!.limits.some(limit => limit.amount.unit === "credits")).toBe(false);
});
