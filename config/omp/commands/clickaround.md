---
description: Drive the app to find UI bugs and UX friction; report numbered findings and fix nothing
---

Drive this repository's app and find as many bugs and rough edges as you can in
the requested focus. This pass finds; it does not fix. The user picks findings
afterwards and runs `/fix-findings`.

The arguments at the end name the focus: surfaces or flows ("today and review
views", "setup to sync"), a bug class ("text entry", "animations and modals",
"visual"), platforms (desktop browser, phone width, Fold, iOS simulator, WebKit
or the desktop shell, a native build), and whether to orchestrate. With no
focus, cover the flows a new user meets first, then the most-used surfaces.

Out of scope unless this invocation asks for it: editing tracked files, commits,
pushes, changing the user's settings or live data, and fixing anything.

Before driving anything:

1. Read the repo's AGENTS.md, the design or spec documents for the surfaces in
   focus, and the repository-local and global skills for this project's
   clickaround, QA, smoke testing, or emulator use. Check `.agents/skills` and
   existing `.omp/skills`. Project skills carry the build steps, seed data,
   ports, selectors, and known traps; where they are more specific than this
   command, follow them.
2. List peer sessions with the intercom tool. Leave their servers, worktrees,
   browser profiles, and dirty files alone.
3. Pin the build under test and record its commit. When the shared tree is dirty
   or a peer is editing it, build from a detached worktree of the commit you
   mean to test.
4. Test against a copy of realistic data: the project's seeded test notebook or
   fixture, or a private copy of the user's data. Never the live data, the
   installed app, or its port. Isolate `HOME` and the `XDG_*` directories for
   anything that writes a registry, lock, or state file.
5. Stay off the user's screen. Use headless browsers with their own
   `--user-data-dir`, emulators, simulators, or background window input on an
   app instance you launched. Do not raise windows, open a visible browser, or
   take over input.

Finding:

- Work alone for a narrow focus. For a broad focus, or when the user says
  orchestrate, fan out finder lanes in one batch: split by surface and viewport,
  and add one code-led lane on the shared primitives (popups, menus, pickers,
  editors) that confirms each suspicion in the running app. Write one contract
  file that every lane reads: build, data copy, port and profile per lane,
  driving recipes, report format, and the rule that finder lanes edit nothing.
- Record each finding with an id (`<Lane>-N`), title, severity (P0 data loss or
  crash, P1 broken flow, P2 wrong or confusing, P3 polish), kind (bug, UX,
  visual, performance, accessibility), platform and viewport, steps, expected,
  actual, a screenshot path, the suspected cause as `file:line`, and a fix idea.
  Lanes write findings to disk as they go.
- Push for depth: keys typed while an async pick or save is pending, rapid
  repeats, undo straight after a commit, reload mid-operation, narrow and wide
  viewports, both themes, empty and very large data. A lane that returns one or
  two findings gets a harder second round.
- Verify before reporting. Independent verifier lanes, or you when working
  alone, reproduce every P0 and P1 and any doubtful item on a fresh data copy
  and mark it confirmed, partial, not reproduced, or duplicate. Move
  unreproduced items to an appendix.

Report:

- Write `report.md` and the screenshots to the repo's existing design folder
  under `~/Documents` (for example `~/Documents/tessera-design`), otherwise
  `~/Documents/<repo>-design`, in a `<YYYY-MM-DD>-<slug>` subfolder.
- Order: data loss and crashes, then regressions with the causing commit when
  known, then one table per surface:
  `# | Spot (shot) | What I saw | Proposal | Sev`, numbered across the whole
  report so the user can answer "fix 1, 4, 9". End with a suggested fix order,
  biggest wins first, and the one to three questions only the user can answer.
- In chat, give counts by severity, the top items, and the report path, then ask
  which numbers to fix.

Cleanup: stop the services and kill the browsers you started (match on your
profile directories), and remove your data copies and worktrees. Keep the
screenshots and the report.

Focus from the user: $ARGUMENTS
