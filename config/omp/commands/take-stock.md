---
description: Read-only stock-take of a repo's backlog, roadmap and health, with the next passes in order
---

Take stock of this repository and recommend what to work on next. This is
read-only: do not edit, commit, prune, or update the board. Offer to update
`TODO.md` or the roadmap, but do it only when asked.

The arguments at the end may narrow the question: an area, `backlog`, `health`,
`roadmap`, or "where were we on <topic>". Without them, cover all of these
briefly.

Gather in one parallel batch:

- The board: `TODO.md`, `BACKLOG*`, `ROADMAP*`, `docs/roadmap.md`, `CHANGELOG`
  "Unreleased", and the open questions in the design docs.
- Repo state: status, the last 25 commits, commits not on upstream, stashes,
  worktrees, branches, and with `gh`, open pull requests, open issues, and the
  last few CI runs.
- Live peers, from the intercom tool's list. Their dirty files and open pull
  requests are theirs.
- History: `archive.sessions` and `archive.recaps` for this project in Python
  eval. A recap ending "Next: …" is a promised follow-up that may never have
  happened, and the same deferred step across several recaps is the real
  blocker. For "where were we on <topic>", find the sessions that last worked on
  it and use the `seance` agent for what they concluded.
- Recent design, QA, and audit reports (`report.md`, and visual `index.html`
  galleries) and editable mockups under `~/artifacts/<project>/`, using the
  stable repository/project name, not an ephemeral worktree name. Explicit
  report/mockup paths or artifact destinations supplied by the user take
  precedence; do not fall back to a legacy discovery location.
- The repo's quick gate, run asynchronously while you read. Rerun a failure
  alone before calling it a regression.
- The managed skill `repo-backlog-review`, which has project probes for Tessera,
  xi, and the site.

Reconcile:

- Check each card against the code: done (cite the commit), still open (cite
  `file:line`), or stale.
- Find work that is done or under way but missing from the board, and decisions
  the board is waiting on.

Report:

- Lead with counts: open cards, stale cards, untracked work, unpushed commits,
  and failing checks.
- Give a table by roadmap stage or area: done, partial, or not started, and what
  remains.
- Recommend three to six next passes in order. For each, give the reason it
  comes before the next, its rough size, whether it suits a `/clickaround`,
  `/audit`, or direct work, and the decisions it needs from the user.
- End by asking which to start.

Focus from the user: $ARGUMENTS
