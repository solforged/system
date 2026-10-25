# commit-msg hook: drop Cursor's agent attribution lines, which Cursor keeps
# adding with its attribution setting off. Cursor's suggested workaround:
# https://forum.cursor.com/t/commit-attribution-opt-out-ignored/164034/5
set -euo pipefail

message_file="${1:-}"
[ -n "$message_file" ] && [ -f "$message_file" ] || exit 0

filtered="$(mktemp)"
trap 'rm -f "$filtered"' EXIT

awk '
  { line = tolower($0) }
  line ~ /cursoragent@cursor\.com/ { next }
  line ~ /^made[ -]with:? *\[?cursor\]?/ { next }
  { print }
' "$message_file" >"$filtered"

if ! cmp -s "$filtered" "$message_file"; then
  cat "$filtered" >"$message_file"
fi
