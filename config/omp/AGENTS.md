# AGENTS.md

## Style

- Write clear, short sentences without fluff, specifically concentrating on avoiding common AI tells ("It's not X, it's Y", "load-bearing")
- Write all headings and titles in sentence case (e.g., "Example heading words", not "Example Heading Words")
- Prefer semicolons, commas, and periods to em dashes.
- Lead directly with the outcome: your first sentence should answer "what happened" or "what did you find", followed by supporting details.

## Rules

- Write commit messages in the `omp commit` style, even when committing by hand:
  - Header: `type(scope): summary`, at most 72 characters in total. The summary starts with a lowercase past-tense verb ("added", "fixed", "moved", "replaced") and has no trailing period.
  - Scope: lowercase, at most two `/`-separated segments of letters, digits, hyphens or underscores. Leave it out when no single area fits.
  - Body (optional): a blank line, then up to six `- ` bullets, each a complete sentence ending in a period, in the past tense like the summary. Wrap body lines at 72 characters and indent continuation lines by two spaces. No prose paragraphs.
  - Say what changed and why it matters. Avoid filler words (comprehensive, various, several, improved, enhanced, better) and meta phrases ("this commit", "this change", "updated code", "modified files").
- Keep Git history linear. Never create merge commits; use fast-forward merges, rebases, or cherry-picks instead.
- Repos whose main requires pull requests (Tessera) land changes with `mise run land`, never by pushing main or by merging with squash or rebase.
- Deliver what was asked at the scope intended. Make routine judgment calls yourself, and check in only when different readings of the request would lead to materially different work.
- If the request seems mistaken or a better approach exists, say so in a single sentence prefixed with 💡 [SUGGESTION] and continue with the task as asked rather than quietly narrowing, widening, or transforming it. Finish the whole task, and stop short of actions that are clearly beyond what was asked.
- You may message other omp sessions over intercom whenever coordination needs it (replying to a peer, claiming or releasing files, handing off work) without asking first.
- In throwaway worktrees and lanes, point Rust builds at the repo's main `target/` with `CARGO_TARGET_DIR` unless the build must stay isolated from it. A separate target dir must use `CARGO_INCREMENTAL=0` and be deleted when the lane ends; each one holds a full multi-GB copy of every dependency.