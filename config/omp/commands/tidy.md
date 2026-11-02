---
description: Survey and prune leftover worktrees, branches, dev servers, browsers, and /tmp debris after agent work
---

Clean up what agent work left behind. Survey first, then ask for one approval of
the exact list. Before approval, remove only processes and paths this session
created.

The arguments at the end may limit the run to `worktrees`, `branches`,
`servers`, `tmp`, `caches`, or a repo. By default, cover this repo's worktrees
and branches, plus servers, headless browsers, and `/tmp` across the machine.
Caches are covered only when named.

Never touch:

- A live peer session's worktrees, servers, browser profiles, or `/tmp` paths.
  Check the intercom tool's list, `ps`, and `lsof`.
- The user's installed apps and their ports.
- Uncommitted or unpushed work.
- Backup refs (`refs/backup/*`, `backup/*` bookmarks) and stashes.
- Anything a managed skill marks as another session's or as a durable cache.

Survey:

1. Worktrees and branches, using the managed skill
   `audit-stale-worktrees-branches`. Classify each as integrated (an ancestor of
   main, patch-identical by `git cherry`, or landed as reworked commits by
   subject and line containment), pending, or unknown. Record whether it is
   dirty and which live session owns it, if any.
2. Servers and browsers: listening ports (`lsof -nP -iTCP -sTCP:LISTEN`) and
   headless browser process trees. Map each to its working directory and owner,
   and mark it orphaned (its session has ended) or live.
3. `/tmp` and caches, using the managed skill `prune-tmp-and-user-caches-macos`
   (the survey steps apply on Linux too). Record sizes, ages, and references
   from running processes or from skills. Before anything is deleted, move items
   with no other copy, such as reports, evidence, SHA maps, and one-off tools,
   to `~/Documents/<area>/`.

Report one table per category, `item | state | evidence | action`, with sizes,
then ask for approval of the exact list.

After approval:

- Stop the approved servers and kill the approved browser trees.
- Remove worktrees with `git worktree remove`. Use `--force` only when the sole
  blocker is an untracked file you have shown to be junk.
- Delete branches with `git branch -d`. Use `-D` only for branches proven landed
  by rebase or cherry-pick, and say which ones. Delete remote branches only when
  they have landed and the approval names them.
- Delete the approved paths, then run `git worktree prune`.
- Report sizes before and after, where salvaged items went, and what you skipped
  and why.

Scope from the user: $ARGUMENTS
