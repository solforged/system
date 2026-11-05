---
description: Fix chosen findings from a clickaround or audit, re-verify them, and commit without publishing
---

Fix the findings the user chose, prove each fix in the running app, and commit
the result. Do not push or land unless this invocation says so.

The arguments at the end name the findings: numbers or ids, ranges, `all`, or
`all but N`, and optionally the report path. An explicit path wins; otherwise use
the findings report from this session, then the newest `report.md` under
`~/artifacts/<project>/`, using the stable repository/project name rather than
an ephemeral worktree name. If the numbers could refer to more than one report,
ask. Decisions in the same message ("portrait only for now", "keep the fold at
860") are binding; record them as settled and do not reopen them.

Out of scope unless this invocation asks for it: pushing, landing, shipping, and
findings the user did not pick. Changes to app-wide defaults, stored data
formats, migrations, or public APIs need the user's approval first; list them
rather than making them.

Before editing:

1. Read the report entries in full, the repo's AGENTS.md, and the
   repository-local and global skills for this project's fix fan-out, smoke
   tests, and landing. Check `.agents/skills` and existing `.omp/skills`.
2. Order the work: data loss first, then root causes shared by several findings,
   then the report's suggested order.
3. List peer sessions with the intercom tool. When the shared tree is dirty or a
   peer is active, work in a fresh worktree from upstream, following the
   worktree rules in AGENTS.md.

Fixing:

- Fix a handful yourself. For more, fan out fix lanes in one batch with disjoint
  file ownership. The contract gives each lane its findings in full, its owned
  paths, any cross-lane API published up front so callers can code against it,
  and these rules: edit only, no builds, tests, or commits; one failing-before,
  passing-after test for each P0 and P1 where practical; report each id as
  fixed, partial, or not fixed, with the files changed.
- Gate once per round with the repo's own check commands. Send each failure back
  to the lane that owns it rather than patching around it.
- Re-QA on a fresh build and a fresh data copy, following `/clickaround`'s
  isolation rules: rerun each finding's steps and mark it fixed, partial, still
  broken, or regressed, and list anything new. Forward items to their owners and
  repeat until nothing is still broken or regressed, or what remains needs the
  user's decision.
- Record re-QA results by the original finding IDs in the same report run,
  preserving the original findings and evidence. Follow AGENTS.md's artifact
  policy: use an owned temporary capture directory, reuse existing evidence,
  and add useful new evidence to that run's `evidence/` with distinct filenames,
  never overwriting before images. Verifiers retain captures only when they add
  different evidence, not duplicate proof. Match viewport, theme, and data state
  for before/after comparisons; identify the tested build. If updating a visual
  gallery, keep severity/IDs independent of gallery order and distinguish the
  implemented result from earlier mockups.

Finish:

- Commit in logical area commits under the `/commit-groups` rules: only your own
  hunks, the AGENTS.md message style, and signed if the repo signs.
- If this invocation says land or ship, continue with `/land`.
- Report a table `# | Status | Commit | Change`, the checks you actually ran,
  items deferred and why, and the decisions you took.
- Stop your services and browsers. Before removing your data copies, scratch
  worktrees, or owned temporary captures, durably preserve all cited evidence,
  mockup sources/assets, and selected plates. Remove only your temporary
  material; remove lane branches once their work is committed, and keep
  unfinished work on interruption.

Findings from the user: $ARGUMENTS
