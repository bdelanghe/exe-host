// /healthz for chitin's socket-only daemons on exe-host: each request dials the daemon's own unix socket with
// {op: "ping"} and answers 200 only on a pong. No cached state, no probe file: a dead socket is a 503 at once.
// Loopback 127.0.0.1:7489; Caddy maps /router/healthz and /notify-sink/healthz here.
import { dial } from "/app/src/socket.ts";
import { sockPath } from "/app/src/paths.ts";

const DAEMONS = new Set(["router", "notify-sink"]);

Bun.serve({
  hostname: "127.0.0.1",
  port: 7489,
  async fetch(req) {
    const m = new URL(req.url).pathname.match(/^\/healthz\/([a-z-]+)$/);
    if (!m || !DAEMONS.has(m[1]!)) return new Response("not found\n", { status: 404 });
    const r = await dial(sockPath(m[1]!), { op: "ping" } as never, 1000);
    if (r.kind === "reply" && (r.reply as { op?: string }).op === "pong") return new Response(`ok ${m[1]}\n`);
    return new Response(`down ${m[1]}: ${r.kind}\n`, { status: 503 });
  },
});
console.log("chitin healthz on 127.0.0.1:7489");
