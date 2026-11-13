---
description: Read-only audit of a feature, surface, or config against a reference, with ranked proposals
---

Audit the subject named at the end against a reference, and propose what to
change. This is read-only: no edits, commits, or settings changes. It asks how
well the subject meets the reference; hunting bugs by driving the app is
`/clickaround`.

The arguments give the subject and, after "against", the reference. Subjects
include a feature, UI surface, MCP or CLI surface, architecture, config, or
plugin. References include a design spec, upstream documentation or release
notes, a URL, another app, or the project's visual language. Without a stated
reference, use the repo's own spec or design docs for the subject; if there are
none, use the upstream documentation for the tool in use. Say which reference
you chose.

Method:

1. Pin the reference. Read the relevant spec sections, or fetch the current
   documentation or release notes and record their versions and URLs. For
   another app or a visual language, capture it first.
2. Inventory the subject as it stands: code paths with `file:line`, config keys,
   tools and commands, UI states. For a UI subject, capture screenshots under
   `/clickaround`'s isolation rules: a data copy, off the user's screen, and
   never the installed app.
3. Compare. Look for gaps (the reference has it, the subject lacks it), drift
   (they differ), excess (the subject has something that no longer earns its
   place), and what holds up well. Ground every claim in a `file:line`, a
   screenshot, or a cited source, and mark inferences as such.
4. Fan out read-only lanes only when the subject splits cleanly, such as per
   surface or per tool group.

Report:

- Start with a short verdict.
- Follow with a numbered table:
  `# | ID | Area | Finding | Evidence | Proposal | Sev | Effort | Impact`. Keep
  stable finding IDs, order by severity, and give a suggested fix order.
- End with the decisions only the user can make.
- Follow AGENTS.md's shared artifact policy. Write long reports or reports with
  durable evidence to a new
  `~/artifacts/<project>/<YYYY-MM-DD>-<topic>/report.md` run unless the user
  supplies a destination. Use the stable project name, not a worktree name, and
  choose a distinct run name rather than overwrite old output.
- Retain report-cited evidence in `evidence/`; source citations and `file:line`
  evidence do not require screenshots. For visual work, inspect captures in a
  task-owned temporary directory and retain one canonical image per finding
  (shared images are fine), with extras only for meaningful state/theme/viewport
  differences. Verifiers record results and reuse evidence, adding captures only
  when they show something different. There is no cap on necessary audit
  evidence.
- For visual deliverables, use `index.html` for editorial order (not finding
  numbering or severity), `mockups/` for editable alternatives/assets, and
  `plates/` for selected captioned renders. Follow the shared policy's gallery
  order and matched-comparison rules; include only stages that exist, clearly
  distinguishing mockups from the running app. Use relative links and create
  only relevant files/directories, not every render or empty scaffolding.
- Remove only owned temporary captures after all cited evidence, mockup
  sources/assets, and selected plates are durably preserved; keep unfinished
  work on interruption. In chat, give the verdict, top proposals, and report
  path.
- Ask which proposals to pursue. `/fix-findings` accepts these numbers.

Subject from the user: $ARGUMENTS
