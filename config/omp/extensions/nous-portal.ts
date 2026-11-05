// Protocol reference: NousResearch/hermes-agent, hermes_cli/auth_nous.py.
// Let omp own persistence and refresh locking: Nous refresh tokens rotate on use.
import { setTimeout as delay } from "node:timers/promises";
import type { ExtensionAPI, ProviderConfig } from "@oh-my-pi/pi-coding-agent";
import type { OAuthCredentials, OAuthLoginCallbacks } from "@oh-my-pi/pi-ai/oauth";
import type { UsageReport } from "@oh-my-pi/pi-ai";

const PORTAL = "https://portal.nousresearch.com";
const INFERENCE = "https://inference-api.nousresearch.com/v1";
// Nous's published public device client; this is not a client secret.
const CLIENT_ID = "hermes-cli";
const SCOPE = "inference:invoke";
const REFRESH_SKEW_MS = 120_000;

type OAuthResponse = {
  access_token?: string;
  refresh_token?: string;
  scope?: string;
  expires_in?: number;
  error?: string;
  device_code?: string;
  user_code?: string;
  verification_uri_complete?: string;
  interval?: number;
};

function requestSignal(signal?: AbortSignal): AbortSignal {
  const timeout = AbortSignal.timeout(15_000);
  return signal ? AbortSignal.any([signal, timeout]) : timeout;
}

async function postOAuth(
  path: string,
  fields: Record<string, string>,
  signal?: AbortSignal,
  refresh?: string,
  fetcher = fetch,
): Promise<{ response: Response; data: OAuthResponse }> {
  const response = await fetcher(`${PORTAL}/api/oauth/${path}`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded",
      ...(refresh ? { "x-nous-refresh-token": refresh } : {}),
    },
    body: new URLSearchParams(fields).toString(),
    signal: requestSignal(signal),
    redirect: "error",
  });
  // Edge-firewall and service failures can return HTML, not OAuth JSON.
  const payload = await response.json().catch(() => ({}));
  const data = (payload && typeof payload === "object" ? payload : {}) as OAuthResponse;
  return { response, data };
}

function exchangeError(response: Response, data: OAuthResponse): Error {
  const code = typeof data.error === "string" && /^[a-z_]+$/.test(data.error) ? data.error : `HTTP ${response.status}`;
  const relogin = ["invalid_grant", "refresh_token_reused", "access_denied", "expired_token"].includes(code);
  // Do not print token endpoint bodies or invalidate credentials on gateway errors.
  return new Error(`Nous Portal: ${code}.${relogin ? " Sign in again with /login nous." : ""}`);
}

function credentials(data: OAuthResponse, previous?: OAuthCredentials): OAuthCredentials {
  const access = data.access_token;
  const refresh = data.refresh_token || previous?.refresh;
  if (typeof access !== "string" || !access || typeof refresh !== "string" || !refresh) {
    throw new Error("Nous Portal returned incomplete OAuth credentials.");
  }
  let claims: Record<string, unknown>;
  try {
    if (access.split(".").length !== 3) throw new Error("not a JWT");
    claims = JSON.parse(Buffer.from(access.split(".")[1], "base64url").toString("utf8"));
    if (!claims || typeof claims !== "object" || Array.isArray(claims)) throw new Error("not JWT claims");
  } catch {
    throw new Error("Nous Portal did not return an inference JWT.");
  }
  const scopes = [data.scope, claims.scope, claims.scp].flatMap(value =>
    typeof value === "string" ? value.split(/\s+/) : Array.isArray(value) ? value : [],
  );
  if (!scopes.includes(SCOPE)) throw new Error("Nous Portal token lacks inference:invoke scope.");
  const expiry = typeof claims.exp === "number" ? claims.exp * 1000
    : typeof data.expires_in === "number" ? Date.now() + data.expires_in * 1000 : NaN;
  if (!Number.isFinite(expiry) || expiry <= Date.now() + REFRESH_SKEW_MS) {
    throw new Error("Nous Portal returned an expired or short-lived inference JWT.");
  }
  return {
    ...previous,
    access,
    refresh,
    expires: expiry - REFRESH_SKEW_MS,
    ...(typeof claims.sub === "string" ? { accountId: claims.sub } : {}),
    ...(typeof claims.org_id === "string" ? { orgId: claims.org_id } : {}),
  };
}

async function login(callbacks: OAuthLoginCallbacks): Promise<OAuthCredentials> {
  const fetcher = callbacks.fetch ?? fetch;
  const started = await postOAuth("device/code", { client_id: CLIENT_ID, scope: SCOPE }, callbacks.signal, undefined, fetcher);
  if (!started.response.ok) throw exchangeError(started.response, started.data);
  const device = started.data;
  if (!device.device_code || !device.user_code || !device.verification_uri_complete ||
      !Number.isFinite(device.expires_in) || device.expires_in! <= 0) {
    throw new Error("Nous Portal returned an incomplete device authorization.");
  }
  const url = new URL(device.verification_uri_complete);
  if (url.origin !== PORTAL) throw new Error("Nous Portal returned an unexpected authorization origin.");
  callbacks.onAuth({ url: url.href, instructions: `Enter code ${device.user_code}. Approve inference access in Nous Portal.` });
  callbacks.onProgress?.("Waiting for Nous Portal authorization…");
  const deadline = Date.now() + device.expires_in! * 1000;
  const timeout = AbortSignal.timeout(device.expires_in! * 1000);
  const signal = callbacks.signal ? AbortSignal.any([callbacks.signal, timeout]) : timeout;
  let interval = Number.isFinite(device.interval) ? Math.max(1, device.interval!) : 5;
  while (Date.now() < deadline) {
    await delay(Math.min(interval * 1000, deadline - Date.now()), undefined, { signal });
    const result = await postOAuth("token", {
      grant_type: "urn:ietf:params:oauth:grant-type:device_code",
      client_id: CLIENT_ID,
      device_code: device.device_code,
    }, signal, undefined, fetcher);
    if (result.response.ok && result.data.access_token) return credentials(result.data);
    if (result.data.error === "authorization_pending") continue;
    if (result.data.error === "slow_down") { interval += 5; continue; }
    throw exchangeError(result.response, result.data);
  }
  throw new Error("Nous Portal device authorization expired. Run /login nous again.");
}

async function refreshToken(previous: OAuthCredentials, signal?: AbortSignal): Promise<OAuthCredentials> {
  const result = await postOAuth("token", { grant_type: "refresh_token", client_id: CLIENT_ID }, signal, previous.refresh);
  if (!result.response.ok) throw exchangeError(result.response, result.data);
  return credentials(result.data, previous);
}

interface CatalogModel {
  id: string;
  name: string;
  context_length: number;
  architecture: { input_modalities: string[]; output_modalities: string[] };
  top_provider?: { max_completion_tokens?: number | null };
  supported_parameters?: string[];
  pricing?: { prompt?: string; completion?: string; input_cache_read?: string; input_cache_write?: string };
}

async function fetchDynamicModels(): Promise<NonNullable<ProviderConfig["models"]>> {
  // The catalog is public. Never send OAuth credentials to discover models.
  const response = await fetch(`${INFERENCE}/models`, { signal: requestSignal(), redirect: "error" });
  if (!response.ok) throw new Error(`Nous model discovery failed (HTTP ${response.status}).`);
  const catalog = await response.json() as { data: CatalogModel[] };
  return catalog.data.filter(model => model.architecture?.output_modalities?.includes("text") && model.context_length > 0).map<NonNullable<ProviderConfig["models"]>[number]>(model => {
    const parameters = model.supported_parameters ?? [];
    const price = (value?: string) => Number(value ?? 0) * 1_000_000;
    return {
      id: model.id,
      name: model.name,
      reasoning: parameters.includes("reasoning") || parameters.includes("reasoning_effort"),
      supportsTools: parameters.includes("tools"),
      input: model.architecture.input_modalities.includes("image") ? ["text", "image"] : ["text"],
      contextWindow: model.context_length,
      maxTokens: model.top_provider?.max_completion_tokens ?? Math.min(16_384, model.context_length),
      cost: {
        input: price(model.pricing?.prompt), output: price(model.pricing?.completion),
        cacheRead: price(model.pricing?.input_cache_read), cacheWrite: price(model.pricing?.input_cache_write),
      },
    };
  });
}

const usage: NonNullable<ProviderConfig["usage"]> = {
  id: "nous",
  retainLastGoodOnFailure: false,
  supports: params => params.provider === "nous" && params.credential.type === "oauth",
  async fetchUsage(params, ctx) {
    if (params.credential.type !== "oauth" || !params.credential.accessToken) return null;
    const response = await ctx.fetch(`${PORTAL}/api/oauth/account`, {
      headers: { Authorization: `Bearer ${params.credential.accessToken}`, Accept: "application/json" },
      signal: requestSignal(params.signal),
      redirect: "error",
    });
    if (!response.ok) throw new Error(`Nous Portal account request failed (HTTP ${response.status}).`);
    const account = await response.json();
    if (!account || typeof account !== "object" || account.error) {
      throw new Error("Nous Portal returned an invalid account report.");
    }
    const window = account.usage_window;
    const limits: UsageReport["limits"] = [];
    const seen = new Set<string>();
    for (const gauge of Array.isArray(window?.gauges) ? window.gauges : []) {
      if (!gauge || typeof gauge.id !== "string" || !gauge.id || seen.has(gauge.id) ||
          !["all", "top_tier"].includes(gauge.scope) || !Number.isInteger(gauge.used_bp) ||
          gauge.used_bp < 0 || gauge.used_bp > 10_000) continue;
      seen.add(gauge.id);
      const label = typeof gauge.label === "string" && gauge.label.trim() ? gauge.label.trim() : gauge.id;
      const reset = gauge.resets_at_ms;
      limits.push({
        id: gauge.id,
        label,
        scope: {
          provider: "nous", accountId: params.credential.accountId, shared: true, windowId: gauge.id,
          ...(gauge.scope === "top_tier" ? { tier: "top_tier" } : {}),
        },
        window: {
          id: gauge.id, label,
          ...(Number.isSafeInteger(reset) && reset > 0 && reset <= Date.now() + 366 * 86_400_000 ? { resetsAt: reset } : {}),
        },
        amount: { used: gauge.used_bp / 100, limit: 100, usedFraction: gauge.used_bp / 10_000, unit: "percent" },
        status: gauge.used_bp === 10_000 ? "exhausted" : gauge.used_bp >= 9000 ? "warning" : "ok",
        notes: [gauge.scope === "top_tier" ? "Applies to top-tier models only." : "Free models do not consume this allowance."],
      });
    }
    // Do not synthesize a blocking credit limit: balances and allowances are
    // separate. Nous enforces model exemptions, pauses, and credit overages.
    const notes = ["Portal enforces model access and credit overages; allowance gauges are informational."];
    if (typeof window?.keep_going_on_credits === "boolean") {
      notes.push(`Continue on credits: ${window.keep_going_on_credits ? "enabled" : "disabled"}.`);
    }
    if (typeof window?.paused_reason === "string" && window.paused_reason) {
      notes.push(`Subscription paused: ${window.paused_reason}.`);
    }
    const balance = account.paid_service_access?.total_usable_credits;
    if (typeof balance === "number" && Number.isFinite(balance)) notes.push(`Credits remaining: ${balance}.`);
    return { provider: "nous", fetchedAt: Date.now(), limits, notes };
  },
};

export default function nousPortal(pi: ExtensionAPI): void {
  pi.registerProvider("nous", {
    baseUrl: INFERENCE,
    api: "openai-completions",
    compat: { thinkingFormat: "openrouter", supportsStore: false, maxTokensField: "max_tokens" },
    oauth: { name: "Nous Portal", login, refreshToken, getApiKey: credential => credential.access },
    fetchDynamicModels,
    usage,
  });
}
