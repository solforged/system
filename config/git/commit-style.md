# Commit style

- Header: `type(scope): summary`, at most 72 characters in total. The summary
  starts with a lowercase past-tense verb ("added", "fixed", "moved",
  "replaced") with no trailing period.
- Scope: lowercase, at most two `/`-separated segments of letters, digits,
  hyphens or underscores. Leave it out when no single area fits.
- Body (optional): a blank line, then up to six `-` bullets, each a complete
  sentence ending in a period, in the past tense like the summary. Wrap body
  lines at 72 characters and indent continuation lines by two spaces. No prose
  paragraphs.
- Say what changed and why it matters.
- Split unrelated changes into separate commits.
