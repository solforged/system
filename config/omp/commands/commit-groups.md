---
description: Split uncommitted (or unpushed) work into logical, signed commits without touching peers' hunks
---

Turn the working tree into a short sequence of logical commits that a reader
could follow. Do not push.

A managed skill named below is at
`~/.omp/agent/managed-skills/<name>/SKILL.md`; read it in full before the
step that uses it.

The arguments at the end may say:

- `plan`: propose the groups and stop for approval.
- `unpushed`: also regroup local commits that are not on upstream.
- `except <paths or feature>`: leave that work uncommitted.
- Paths or a feature name: commit only that.

By default, commit every uncommitted change that is not a live peer's.

Out of scope unless this invocation asks for it: push, `jj git push`,
`ts-land`, rewriting commits that are already on a remote, and squashing
peers' commits.

Before committing:

1. If `jj root` succeeds, this is a jj working copy even when `.git` is present.
   Use jj, not `git commit`, `git add`, or `git reset` underneath it.
2. List peer sessions with the intercom tool. Dirty files or hunks belonging to
   a live peer stay uncommitted unless the user says otherwise; ask the peer
   when ownership is unclear. Uncommitted work with no live owner is the user's
   and is in scope.
3. Save the full diff against `HEAD` (or `@-` in jj) to a temp file, so you can
   prove at the end that nothing was lost or changed.
4. Read every hunk. Group by intent, not by file: one feature, fix, or refactor
   per commit, ordered so each builds on the last and history reads like the
   project growing. A file may span several groups.

Grouping:

- In git, never `git add -A` or `git commit -- <path>` on a file that holds
  someone else's hunks. Stage each group's content without touching the working
  tree: build the blob from `HEAD` plus that group's hunks, write it with
  `git hash-object -w`, and stage it with `git update-index --cacheinfo`. The
  managed skill `shared-tree-hunk-commits` has the method and the checks.
- In jj, commit whole-file groups with `jj commit -m <message> <paths>`. For a
  group that splits a file, write the file as the base plus the cumulative hunks
  of groups so far, run `jj commit` on those paths, then restore the final
  content. Do this only when no live peer is editing that file; otherwise ask.
- Messages follow `~/.config/git/commit-style.md` and the repo's
  `.commit-style.md`, if any: `type(scope): summary` in the past tense, at most
  72 characters, with an optional body of up to six bullets wrapped at 72.
- Sign the commits if the repo signs (`git config commit.gpgsign`, or
  `signing.behavior` in jj; use `jj sign` when jj leaves them unsigned). Check
  `%G?` afterwards.
- For `unpushed`: write a backup ref first
  (`refs/backup/<branch>-pre-regroup-<YYYYMMDD>`, or a jj bookmark of that
  name). Regroup only commits that are not on any remote, keep their approximate
  author dates, and never create merge commits.

Verify:

- The remaining uncommitted diff, plus everything you committed, equals the
  saved diff, byte for byte. Peers' hunks are unchanged.
- Each commit stands alone: run the repo's quick check (type check, build, or
  flake evaluation) on each commit in a detached worktree. Run the full checks on the tip. Point Rust
  builds at the main `target/`.

Report a table `commit | summary | files`, what you left uncommitted and whose
it is, the checks you ran, and the backup ref if you made one. With `plan`, show
the same table as a proposal and stop.

Scope from the user: $ARGUMENTS
