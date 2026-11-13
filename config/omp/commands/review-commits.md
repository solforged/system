---
description: Propose a more logical split of the last N commits, defaulting to all unpushed
---

Review the last N first-parent commits, or all unpushed commits when N is
omitted. N must be a positive integer. Use jj when present, otherwise Git;
exclude uncommitted work. Determine unpushed history from locally known remote
refs without fetching; ask for N if none exist. State the selected scope and
flag published commits or merge constraints.

Read each commit's full diff. Group by intent, not file or existing boundaries:
split unrelated work, combine scattered changes and fixups, and order groups by
dependency. Keep tests and docs with their behavior; preserve the final result.
Leave sound boundaries alone.

Give a brief verdict and an oldest-first table:
`proposed subject | source commits and files/hunks | rationale / dependencies`.
Follow repo commit-message rules and account for every selected commit.

Proposal only: no edits, history changes, builds, tests, fetches, or pushes.

N: $ARGUMENTS
