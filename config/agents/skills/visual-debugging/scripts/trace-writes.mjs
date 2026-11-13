// Logs what a Node terminal program draws, with timings, so flicker, reflow and
// redraw storms can be read back as text. Load it before the program:
//
//   TRACE_FILE=/tmp/trace.log node --import /path/to/trace-writes.mjs program.js
//
// Or, when you cannot change the command line, add a temporary first import to
// the program: `try { await import("/path/to/trace-writes.mjs"); } catch {}`.
//
// Each line: milliseconds since start, then one of
//   start   the terminal size at launch
//   write   a stdout write: size at the time, bytes, cursor moves to column 1
//           (roughly, rows repainted) and the first characters
//   resize  a SIGWINCH and the new size
//   stdin   input received, only with TRACE_STDIN=1: listening starts stdin
//           flowing early, which can change how the program reads input
import { appendFileSync } from "node:fs";

const file = process.env.TRACE_FILE || "/tmp/trace-writes.log";
const t0 = performance.now();
const log = (line) => { try { appendFileSync(file, `${(performance.now() - t0).toFixed(1).padStart(8)} ${line}\n`); } catch {} };
const size = () => `${process.stdout.columns}x${process.stdout.rows}`;
const preview = Number(process.env.TRACE_PREVIEW || 60);

const write = process.stdout.write.bind(process.stdout);
process.stdout.write = (chunk, ...rest) => {
  const text = String(chunk);
  const rows = (text.match(/\x1b\[\d+;1H/g) ?? []).length;
  log(`write  ${size()} bytes=${text.length} rows=${rows} ${JSON.stringify(text.slice(0, preview))}`);
  return write(chunk, ...rest);
};
process.stdout.on("resize", () => log(`resize ${size()}`));
if (process.env.TRACE_STDIN === "1") process.stdin.on("data", (data) => log(`stdin  ${JSON.stringify(String(data)).slice(0, preview)}`));
log(`start  ${size()} pid=${process.pid}`);
