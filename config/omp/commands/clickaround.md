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
   take over input. The one exception is a focus that asks to watch: inside Rex,
   open a single terminal-browser pane beside this session with
   `terminal-browser open <url> --split right` and drive it with
   `terminal-browser action`, following its skill. Finder lanes stay headless.

Finding:

- Work alone for a narrow focus. For a broad focus, or when the user says
  orchestrate, fan out finder lanes in one batch: split by surface and viewport,
  and add one code-led lane on the shared primitives (popups, menus, pickers,
  editors) that confirms each suspicion in the running app. Write one contract
  file that every lane reads: build, data copy, port and profile per lane,
  driving recipes, report format, the artifact run and task-owned temporary
  capture directory, and the rule that finder lanes edit no app files. Assign
  evidence paths per lane so lanes cannot overwrite one another.
- Record each finding with an id (`<Lane>-N`), title, severity (P0 data loss or
  crash, P1 broken flow, P2 wrong or confusing, P3 polish), kind (bug, UX,
  visual, performance, accessibility), platform and viewport, steps, expected,
  actual, evidence path, the suspected cause as `file:line`, and a fix idea.
  Lanes write findings to disk as they go. Capture and inspect freely in their
  owned temporary directories; when an image is useful, promote one canonical
  image per finding to `evidence/` (findings may share one). Keep extra images
  only when transitions, themes, or viewports add evidence, not every shot or
  retry.
- Push for depth: keys typed while an async pick or save is pending, rapid
  repeats, undo straight after a commit, reload mid-operation, narrow and wide
  viewports, both themes, empty and very large data. A lane that returns one or
  two findings gets a harder second round.
- Verify before reporting. Independent verifier lanes, or you when working
  alone, reproduce every P0 and P1 and any doubtful item on a fresh data copy
  and mark it confirmed, partial, not reproduced, or duplicate. Verifiers record
  their results and reuse finder evidence; persist their own captures only when
  they add different evidence. Move unreproduced items to an appendix.

Report:

- Follow AGENTS.md's shared artifact policy. Unless the user gives a
  destination, create a new run at
  `~/artifacts/<project>/<YYYY-MM-DD>-<topic>/`, using the stable
  repository/project name, not an ephemeral worktree name. Never overwrite a
  prior run; choose a distinct run name if the path already exists.
- Write `report.md` at the run root and report-cited evidence in `evidence/`.
  For visual deliverables, write `index.html` for editorial order, selected
  captioned renders in `plates/`, and any editable HTML/CSS/SVG alternatives
  with required assets in `mockups/`. Create only relevant files/directories.
  Use relative links and numbered descriptive visual filenames; captions explain
  what changed and why, and distinguish mockups from the running app.
- Keep the report severity-ordered: data loss and crashes first, then P1 through
  P3, noting regressions and causing commits when known. Use
  `# | ID | Surface (evidence) | What I saw | Proposal | Sev`, with stable
  finding IDs and report-wide numbers so the user can answer "fix 1, 4, 9". End
  with a suggested fix order, biggest wins first, and the one to three questions
  only the user can answer.
- Gallery order is separate from severity and finding IDs: problem, alternatives
  considered, chosen direction, implemented result, remaining questions. Include
  only stages that exist; never imply a mockup was implemented. Aim for 4–8
  reader-facing plates in an ordinary design story, not a cap on audit evidence.
  Match viewport, theme, and data state for before/after comparisons.
- In chat, give counts by severity, the top items, and the report path, then ask
  which numbers to fix.

Cleanup: stop the services, kill the browsers you started (match on your
profile directories), and close any terminal-browser pane you opened. Before
removing your data copies, worktrees, or owned temporary captures, durably
preserve all cited evidence, editable mockup sources/assets, and selected
plates. Remove only this session's temporary material; keep unfinished work on
interruption and preserve existing artifacts.

Focus from the user: $ARGUMENTS
