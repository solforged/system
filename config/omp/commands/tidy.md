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
- Existing material under `~/Documents`; it is not a migration or cleanup
  target.

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
   from running processes or from skills. Identify genuinely unique durable
   items before proposing deletion: reports and their cited evidence, editable
   mockup sources/assets, selected plates, or useful SHA maps and one-off tools
   with no other copy. Do not promote every diagnostic capture, retry, or
   intermediate render; preserve unfinished work on interruption.
4. Propose salvage into a new dated run at
   `~/artifacts/<project>/<YYYY-MM-DD>-<topic>/`, unless the user supplies a
   destination. Use the stable project name, not a worktree name; never
   overwrite an existing run or evidence. Follow AGENTS.md's artifact policy:
   place report-cited evidence in `evidence/`, editable mockups/assets in
   `mockups/`, and selected captioned renders in `plates/`, creating only
   relevant directories. Preserve report/gallery relative links when salvaging.
   Include the exact salvage sources and destinations in the approval list.

Report one table per category, `item | state | evidence | action`, with sizes,
then ask for approval of the exact list.

After approval:

- Stop the approved servers and kill the approved browser trees.
- Remove worktrees with `git worktree remove`. Use `--force` only when the sole
  blocker is an untracked file you have shown to be junk.
- Delete branches with `git branch -d`. Use `-D` only for branches proven landed
  by rebase or cherry-pick, and say which ones. Delete remote branches only when
  they have landed and the approval names them.
- Before deleting approved paths, durably preserve the approved unique items and
  all cited evidence, required mockup sources/assets, and selected plates. If
  required material cannot be preserved, skip that deletion. Delete only the
  approved paths, then run `git worktree prune`. This session's own temporary
  captures may be removed without approval only after the same preservation rule
  is satisfied; never remove another session's unapproved captures.
- Report sizes before and after, where salvaged items went, and what you skipped
  and why.

Scope from the user: $ARGUMENTS
