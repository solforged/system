---
description: Reconcile the current checkout with upstream, without publishing
---

Reconcile this checkout with its upstream. Keep unique local commits and
uncommitted work. Leave history linear. Do not publish.

Upstream is the upstream of the current branch. In git that is `@{upstream}`
when it is set, otherwise `origin`'s default branch if that remote exists. In a
jj working copy it is the remote bookmark, `main@origin` for `main`;
`origin/main` is not a jj revision. `$ARGUMENTS` may name a different ref.
Package upstreams, dependency pins, and open pull requests are not the target
unless the argument says so. Fetch before comparing. Do not reconcile against a
stale remote-tracking ref.

Out of scope unless this invocation asks for it: push, `jj push`,
`mise run land`, ship, force-push, opening a pull request, dependency-wide lock
updates, deleting backup refs, stashes, or worktrees you did not create, and
rebuilding, switching or restarting the system.

Before moving any ref:

1. If `jj root` succeeds, this is a jj working copy even when `.git` is present.
   Use jj. Do not `git rebase`, `git merge`, `git pull`, or `git reset`
   underneath it. jj imports those moves and can detach the working copy.
2. Record the branch, the upstream ref, ahead/behind, every local-only commit
   (subject, sha, and change-id when jj has one), dirty paths, any in-progress
   rebase or merge, other worktrees, and stashes. If a rebase or merge is
   already in progress, stop and report it. Do not continue someone else's
   operation.
3. List peer sessions with the intercom tool. If another session has this
   checkout open, send an aside that names the refs you intend to move and asks
   it to pause edits there. Do not rewrite a dirty shared tree while that work
   is unanswered.
4. Map every dirty path. Uncommitted work you did not make belongs to a peer.
   Never `git add -A`. Never `git commit -- <path>` on a mixed file: that
   commits the whole worktree file and sweeps in the peer's hunks. Never stash,
   reset, or checkout over a peer's edits to make the reconcile fit.
5. Write a backup ref before the first move, and leave it:
   `refs/backup/<branch>-pre-reconcile-<YYYYMMDD>` in git, or a jj bookmark of
   that name. Do not delete it in this run.

A local-only commit is not unique until you prove it.
`git cherry -v <upstream> <local>` works in a colocated repo. A leading `-` is
patch-identical and already upstream. A leading `+` is not proof of unique work:
match by subject, then `git range-diff` or `jj diff` between the two commits. A
conflict-resolved replay that already landed still supersedes the local commit
when the change is the same. The same jj change-id on both sides is the same
change; keep the upstream commit.

Then do one of these, and no other:

- Nothing local is unique, and the tree is clean. Move the branch to upstream.
  In git, fast-forward with `git merge --ff-only` when that is a fast-forward;
  use `git reset --keep` only when every local commit is superseded and
  `git status --porcelain` is empty. Never `reset --hard`. In jj,
  `jj bookmark set <branch> -r <remote-bookmark> --allow-backwards`, then leave
  `@` as an empty child of that commit (`jj new` if the working copy is still on
  the old parent). An empty `@` with no description is normal; do not treat it
  as a commit to keep or as dirty work. Do not `jj abandon` a commit until you
  have proved it is superseded. After moving the bookmark, Git HEAD may still be
  detached even though `refs/heads/<branch>` is correct. `git switch <branch>`
  reattaches HEAD without rewriting commits; do this only when the working tree
  permits it.
- Behind only, and the tree is clean. Fast-forward. Do not create a merge
  commit.
- Some commits are unique. Rebase those onto upstream. Do not squash, and do not
  merge. `git merge` and `git pull` without `--ff-only` are how a merge commit
  lands on main; if one appears, abort it and rebase instead. In jj, rebase only
  the unique commits (`jj rebase -s <oldest unique> -o <remote-bookmark>`, or
  `-r` when the unique set is not a single suffix). Do not
  `jj rebase -b <branch>` across commits you have already proved are upstream.
  If `revsets.bookmark-advance-to` is `@-`, the branch bookmark stays on the
  commit under `@`, not on the empty working-copy commit.
- Unique commits, and the shared tree is dirty. Rebase in a detached worktree
  taken from the local tip. Do not move the shared branch until the result is
  verified and the shared working copy has no peer edits. In git,
  `git reset --keep <new-tip>` once `git status --porcelain` is empty. In jj,
  move the bookmark the same way as a clean superseded branch, and only then. If
  the shared tree is dirty, stop and report. Do not stash a peer's work to force
  the move. A private worktree may rebase in place.

Conflicts:

- Read both sides. Keep both when they add different behavior. Do not drop a
  side to get a clean tree.
- `rerere` may pre-resolve. Read `git diff --cc` before accepting a resolution.
- Do not splice a lockfile (`flake.lock`, `Cargo.lock`, `bun.lock`) by hand.
  Check out one parent and re-run the lock command the local commit performed,
  or keep upstream's lock when that change is already upstream.
- If the intent of a conflict is unclear, stop and ask. Do not guess.
- Continue with `GIT_EDITOR=true`. If the repo signs commits, rebase with `-S`.
  `git commit-tree` does not sign unless `-S` is passed. `jj duplicate` drops
  signatures. If you duplicate commits before rebasing, sign the resulting
  commits with `jj sign` before moving the branch bookmark.
- If a peer already has the same tree and a valid signature, adopt that commit.
  Do not keep a second copy.

Verify before moving a shared branch, and again after:

- Upstream is an ancestor of the result.
- `git log --merges <upstream>..HEAD` is empty.
- Every unique local commit is in the result, and every superseded one is absent
  rather than duplicated.
- Peer dirty files are unchanged. Your own uncommitted work is still
  uncommitted.
- Run the checks that cover files the rebase changed, using the repo's own
  commands. In a throwaway worktree, symlink `node_modules` from the main tree
  as a single link; never nest a link inside an existing `node_modules` (that
  bundles a library twice and the app comes up blank). Point Rust builds at the
  main `target/` with `CARGO_TARGET_DIR` unless the build must stay isolated. Do
  not create a second target directory.

Finish:

- Remove only the worktree and temp directories you created. A worktree remove
  refuses untracked files; delete the symlink you added, then remove the
  worktree. Do not force-remove a worktree you did not create.
- Tell each peer the old and new ids. Intercom does not accept `to: all`;
  address each session.
- Report the upstream ref, ahead/behind before and after, old to new for each
  kept commit, which local commits were already upstream, each conflict and how
  it was resolved, the checks you ran, the backup ref, and that nothing was
  pushed.

Optional focus from the user: $ARGUMENTS
