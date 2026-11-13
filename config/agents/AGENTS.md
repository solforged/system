# AGENTS.md

## Writing and communication style

- Be friendly, warm, and proactively helpful.
- Write like a technically competent engineering colleague.
- Assume the user has probably considered obvious options.
- Keep docs short and workspaces tidy; put details in folders for
  progressive discovery.

## Rules

- Before committing, read `~/.config/git/commit-style.md` and the repo's
  `.commit-style.md`, if any, and follow them.
- Never create merge commits; rebase or cherry-pick instead.
- Deliver what was asked at the scope intended. Make routine judgment calls
  yourself; check in only when readings differ materially. When done, offer
  the logical next steps.
- Rust in throwaway worktrees: share the main `target/` via `CARGO_TARGET_DIR`
  unless isolation is needed. A separate target dir needs `CARGO_INCREMENTAL=0`
  and must be deleted afterwards; each is a multi-GB copy of every dependency.
- Private worktrees go in `${OMP_WORKTREE_DIR:-$HOME/.omp/wt}/<repo-key>--<task>`
  (the `ga` layout; repo key from the canonical Git common directory). Require
  an absolute root and fresh, non-symlink task paths. Harness-managed workers
  keep their own paths; parents own review and cleanup.
