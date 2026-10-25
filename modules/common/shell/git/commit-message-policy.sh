# commit-msg hook: Conventional Commits header with a lowercase description,
# and a short body.
set -euo pipefail

message_file="${1:-}"
if [ -z "$message_file" ] || [ ! -f "$message_file" ]; then
  echo "commit-msg: missing commit message file, refusing to commit." >&2
  exit 1
fi

comment_char="$(git config --get core.commentChar 2>/dev/null || true)"
if [ -z "$comment_char" ] || [ "$comment_char" = "auto" ]; then
  comment_char="#"
fi

normalize_message() {
  awk -v comment_char="$comment_char" '
    index($0, comment_char) == 1 && index($0, ">8") { exit }
    index($0, comment_char) != 1 { print }
  ' "$1" | git stripspace
}

message="$(normalize_message "$message_file")"
rebase_head="$(git rev-parse -q --verify 'REBASE_HEAD^{commit}' 2>/dev/null || true)"
if [ -n "$rebase_head" ] && [ "$message" = "$(git log -1 --format=%B "$rebase_head" | git stripspace)" ]; then
  exit 0
fi

printf '%s\n' "$message" |
  awk '
    NR == 1 {
      if ($0 !~ /^[[:lower:]]+(\([^)]*\))?!?: [[:lower:]]/) {
        print "commit-msg: header must use Conventional Commits and start its description with a lowercase letter." > "/dev/stderr"
        invalid = 1
      }
      next
    }

    NR == 2 && $0 == "" { next }

    {
      if (body_lines > 0) {
        body_chars++
      }
      body_chars += length($0)
      body_lines++

      if ($0 == "") {
        in_paragraph = 0
      } else if (!in_paragraph) {
        paragraphs++
        in_paragraph = 1
      }
    }

    END {
      if (body_chars > 1200) {
        printf "commit-msg: body is %d characters; maximum is 1200.\n", body_chars > "/dev/stderr"
        invalid = 1
      }
      if (paragraphs > 3) {
        printf "commit-msg: body has %d paragraphs; maximum is 3.\n", paragraphs > "/dev/stderr"
        invalid = 1
      } else if (paragraphs > 1) {
        printf "commit-msg: body has %d paragraphs; 1 is preferred.\n", paragraphs > "/dev/stderr"
      }
      exit invalid
    }
  '
