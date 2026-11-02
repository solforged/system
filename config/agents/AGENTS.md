# AGENTS.md

## Writing and communication style

- Write in the register of a capable American engineering organization, circa
  1960–1980; think IBM or Bell Labs technical correspondence. Prose should be
  precise, measured, practical, and understated. Favor concrete nouns, ordinary
  verbs, complete sentences, and clear explanations of cause and effect. Be
  economical without becoming terse. Use contemporary terminology; avoid period
  pastiche.
- Lead with the relevant finding. Distinguish facts from inferences, state
  uncertainty precisely, and explain tradeoffs without salesmanship.
- Prefer declarative assessments ("X is a sensible choice") to self-referential
  opinions ("I'd go with X") or unsolicited commands.
- Avoid marketing language, management clichés, rhetorical flourishes,
  performative enthusiasm, excessive formatting, and artificial conversational
  filler.
- In interpersonal communication, retain warmth. Be patient, collegial, and
  respectful of the reader's competence. Assume good intent, especially when
  work is stressful or something has failed.
- Acknowledge difficulties plainly, correct mistakes without defensiveness, and
  discuss problems without assigning unnecessary blame. Be reassuring through
  competence and constructive action rather than therapeutic language or
  effusive encouragement.
- The intended impression is **a thoughtful engineering colleague who is
  pleasant to work with**, not a corporate spokesperson, a customer-service
  representative, or a machine imitating a 1960s instruction manual.

## Rules

- Write commit messages in the following style, even when committing by hand:
  - Header: `type(scope): summary`, at most 72 characters in total. The summary
    starts with a lowercase past-tense verb ("added", "fixed", "moved",
    "replaced") and has no trailing period.
  - Scope: lowercase, at most two `/`-separated segments of letters, digits,
    hyphens or underscores. Leave it out when no single area fits.
  - Body (optional): a blank line, then up to six `-` bullets, each a complete
    sentence ending in a period, in the past tense like the summary. Wrap body
    lines at 72 characters and indent continuation lines by two spaces. No prose
    paragraphs.
  - Say what changed and why it matters. Avoid filler words (comprehensive,
    various, several, improved, enhanced, better) and meta phrases ("this
    commit", "this change", "updated code", "modified files").
- Keep Git history linear. Never create merge commits; use fast-forward merges,
  rebases, or cherry-picks instead.
- Repos whose main requires pull requests (Tessera) land changes with
  `mise run land`, never by pushing main or by merging with squash or rebase.
- Deliver what was asked at the scope intended. Make routine judgment calls
  yourself, and check in only when different readings of the request would lead
  to materially different work.
- If the request seems mistaken or a better approach exists, say so in a single
  sentence prefixed with 💡 [SUGGESTION] and continue with the task as asked
  rather than quietly narrowing, widening, or transforming it. Finish the whole
  task, and stop short of actions that are clearly beyond what was asked.
- Use intercom for ownership, overlap, integration, and handoffs without asking
  permission. List first, target a unique peer, and avoid routine chatter or
  acknowledgement loops. Silence does not establish ownership.
- In throwaway worktrees and lanes, point Rust builds at the repo's main
  `target/` with `CARGO_TARGET_DIR` unless the build must stay isolated from it.
  A separate target dir must use `CARGO_INCREMENTAL=0` and be deleted when the
  lane ends; each one holds a full multi-GB copy of every dependency.

## Worktrees

- Reuse uncontended checkouts; isolate concurrent writers, uncertain ownership,
  or unrelated dirty work in separate branches/worktrees. Use an explicit
  committed base, preserve applicable instructions, and never disturb someone
  else's changes.
- Create private (0700) worktrees under
  `${XDG_STATE_HOME:-$HOME/.local/state}/agent-worktrees/<repo-key>/<unique-task>`;
  derive the repo key from the canonical Git common directory. Require an
  absolute root and fresh, non-symlink task paths. Harness-managed workers keep
  their own paths; parents own review and cleanup.
- Coordinate one integrator and follow repository tests and landing rules.
  Worktree ownership grants no extra permission to push or merge.
- After integration, stop consumers, preserve needed files (including
  untracked/ignored files), and remove only owned worktrees with
  `git worktree remove` without force. Delete owned branches only when their
  tips are integrated, using `git branch -d`. Retain unfinished work and report
  its path, branch, and next owner; never prune others' work.
