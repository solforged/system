import assert from "node:assert/strict";
import { EventEmitter, once } from "node:events";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import net from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setImmediate } from "node:timers/promises";
import { pathToFileURL } from "node:url";

const source = process.argv[2];
const text = await readFile(source, "utf8");
assert.match(text, /HERDR_INTEGRATION_ID=pi/);
assert.match(text, /HERDR_INTEGRATION_VERSION=\d+/);

const dir = await mkdtemp(join(tmpdir(), "herdr-pi-"));
const requests = [];
const events = new EventEmitter();
const server = net.createServer((socket) => {
  socket.setEncoding("utf8");
  let buffer = "";
  socket.on("data", (chunk) => {
    buffer += chunk;
    for (let newline; (newline = buffer.indexOf("\n")) !== -1;) {
      const request = JSON.parse(buffer.slice(0, newline));
      buffer = buffer.slice(newline + 1);
      requests.push(request);
      socket.write(JSON.stringify({ id: request.id, result: {} }) + "\n");
      events.emit("request");
    }
  });
});

try {
  const socketPath = join(dir, "herdr.sock");
  server.listen(socketPath);
  await once(server, "listening");
  process.env.HERDR_ENV = "1";
  process.env.HERDR_PANE_ID = "w1:p1";
  process.env.HERDR_SOCKET_PATH = socketPath;
  const { default: register } = await import(pathToFileURL(source).href);
  const handlers = new Map();
  register({
    on: (name, handler) => handlers.set(name, handler),
    events: { on() {} },
  });
  let idle = true;
  const ctx = {
    mode: "tui",
    isIdle: () => idle,
    sessionManager: {
      getSessionFile: () => join(dir, "session.jsonl"),
      getSessionId: () => "test-session",
    },
  };
  for (const mode of ["print", "json", "rpc"]) {
    await handlers.get("session_start")({ reason: "startup" }, { ...ctx, mode });
  }
  await setImmediate();
  assert.deepEqual(requests, [], "headless children must not report the parent pane");

  let cursor = 0;
  async function waitForState(state) {
    const signal = AbortSignal.timeout(5000);
    for (;;) {
      const index = requests.findIndex((request, i) => i >= cursor &&
        request.method === "pane.report_agent" && request.params.state === state);
      if (index !== -1) {
        cursor = index + 1;
        return;
      }
      await once(events, "request", { signal });
    }
  }
  await handlers.get("session_start")({ reason: "startup" }, ctx);
  await waitForState("idle");
  idle = false;
  handlers.get("agent_start")({}, ctx);
  await waitForState("working");
  idle = true;
  handlers.get("agent_settled")({}, ctx);
  await waitForState("idle");
  assert.ok(requests.some((request) => request.method === "pane.report_agent_session"));
  let seq = 0;
  for (const request of requests) {
    assert.equal(request.params.source, "herdr:pi");
    assert.equal(request.params.pane_id, "w1:p1");
    assert.equal(request.params.agent, "pi");
    assert.equal(request.params.agent_session_path, ctx.sessionManager.getSessionFile());
    assert.ok(request.params.seq > seq, "reports must have increasing sequence numbers");
    seq = request.params.seq;
  }
  console.log("Pinned Herdr TUI integration reported session and lifecycle; headless modes stayed silent.");
} finally {
  await new Promise((resolve) => server.close(resolve));
  await rm(dir, { recursive: true, force: true });
}
