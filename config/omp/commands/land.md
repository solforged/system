---
description: Land finished work on upstream main by the repo's own rules, and ship it when asked
---

Publish finished work from this checkout to upstream main, keeping history
linear. Ship it only when this invocation asks.

The arguments at the end may name the branch, commits, or worktree to land, a
pull request title, `ship` to run the repo's ship step after landing, or `wip`
to allow a `wip(scope): …` checkpoint. Without arguments, land the current
branch's commits that are not on upstream.

Out of scope unless this invocation asks for it: force-pushing main, merge
commits, squash or rebase merges of pull requests, releases and tags,
`nix flake update`, and rebuilding or switching a system.

Find the landing rule, in this order:

1. The repo's AGENTS.md and contributor docs.
2. A `land` task (`mise tasks`). Tessera's main is protected: push a branch,
   then `mise run land -- --title "type(scope): summary" --wait <branch>`. Never
   push main there.
3. Branch protection, when `gh` works
   (`gh api repos/{owner}/{repo}/branches/main/protection`).
4. Otherwise, a fast-forward push of main.

Before publishing:

1. If `jj root` succeeds, use jj. Do not run `git rebase`, `git merge`,
   `git pull`, or `git reset` underneath it.
2. Uncommitted work in scope gets committed under the `/commit-groups` rules.
   Leave everything else uncommitted.
3. Fetch, then list exactly what will publish:
   `git log --oneline <upstream>..<ref>`. Every local ancestor goes with it. If
   that includes commits you did not make and were not asked to land (a peer's,
   or the user's unpushed work), stop and ask. Also stop on `wip:` subjects
   (unless `wip` was given), `fixup!` commits, unsigned commits in a repo that
   signs, or messages that break the AGENTS.md commit rules.
4. List peer sessions with the intercom tool. Tell live peers in this repo that
   you are about to move main, and ask them to hold their own landings.
5. Rebase onto upstream; never merge. Run the repo's checks for the changed
   files on the rebased commits, in a detached worktree when the shared tree is
   dirty. Point Rust builds at the main `target/`.

Publish:

- Pull-request repos: push the branch, run the land task with `--wait`, and
  follow the project's landing skill (Tessera: `tessera-integration-landing`).
  If main moves mid-land, rebase, update the branch with `--force-with-lease` on
  that branch only, and run land again with the same branch.
- Other repos: fast-forward push, `git push origin <ref>:main`. In jj,
  `jj bookmark set main -r <rev>`, then `jj git push -b main`. If the push is
  rejected, fetch, rebase, re-verify, and retry once before reporting.
- Confirm the landed SHA is an ancestor of `origin/main`.

Ship, only when asked:

- Run the repo's ship step against the landed SHA (Tessera:
  `mise run ship <sha>` from `~/src/tessera`, then confirm the live service
  reports that build). For an app, ship means the user's installed copy; for a
  system flake, it means a switch.
- If shipping needs something you cannot do, such as `sudo`, a device approval,
  or a physical device, give the user the exact command instead.

Afterwards:

- Bring the shared checkout's main up to date only if it is clean:
  `git merge --ff-only`, or `git reset --keep` once every local commit is
  upstream.
- Tell peers the new SHAs. Rebases change them.
- Remove the worktrees and branches you created for this work, now that they are
  integrated (`git worktree remove`, `git branch -d`).
- Report the landed SHAs (old to new if rebased), the pull request and CI links,
  the checks you ran, the shipped build, and anything left unpushed.

Target from the user: $ARGUMENTS
