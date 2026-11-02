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
  `# | Area | Finding | Evidence | Proposal | Effort | Impact`. Rank the
  proposals and give a suggested order.
- End with the decisions only the user can make.
- Write long reports, or any with screenshots, to the repo's design folder under
  `~/Documents` (`<YYYY-MM-DD>-<slug>`). In chat, give the verdict, the top
  proposals, and the path.
- Ask which proposals to pursue. `/fix-findings` accepts these numbers.

Subject from the user: $ARGUMENTS
