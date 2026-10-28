# jj push: Git's commit-msg and pre-commit checks, run over every commit a
# push could publish, then `jj git push` with the same arguments. jj has no
# hooks, so this is the only place the policies see jj's commits.
set -euo pipefail

root="$(jj root)"
# The checks read remotes, config and .gitleaks.toml through git. Only a
# colocated repo has a .git, so name jj's backing repo explicitly.
git_dir="$(jj git root)"
in_git() {
  GIT_DIR="$git_dir" GIT_WORK_TREE="$root" "$@"
}

# Every local bookmark, plus the revisions -r, -c and --named point at, which
# have no bookmark until the push creates one.
targets="bookmarks()"
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  arg="${args[i]}"
  next="${args[i + 1]:-none()}"
  case "$arg" in
    -r | -c | --revision | --change) targets+=" | ($next)" ;;
    --revision=* | --change=*) targets+=" | (${arg#*=})" ;;
    -r?* | -c?*) targets+=" | (${arg:2})" ;;
    --named) targets+=" | (${next#*=})" ;;
    --named=*)
      named="${arg#--named=}"
      targets+=" | (${named#*=})"
      ;;
  esac
done
revs="mutable() & (remote_bookmarks()..($targets))"

jj --quiet util snapshot
jj_log() {
  jj log --ignore-working-copy --no-graph --color=never "$@"
}

commits="$(jj_log -r "$revs" -T 'commit_id ++ " " ++ change_id.shortest(8) ++ "\n"')"
if [ -z "$commits" ]; then
  exec jj git push "$@"
fi

failed=0
msg="$(mktemp "${TMPDIR:-/tmp}/jj-push-msg.XXXXXX")"
trap 'rm -f "$msg"' EXIT

while read -r commit change; do
  jj_log -r "$commit" -T description >"$msg"
  # jj git push refuses undescribed commits on its own.
  [ -s "$msg" ] || continue
  if ! in_git git-commit-message-policy "$msg"; then
    echo "jj push: $change breaks the commit-message policy; fix it with jj describe -r $change." >&2
    failed=1
  fi
done <<<"$commits"

# One scan over what the push publishes: identities, messages, added lines.
if ! {
  jj_log -r "$revs" -T 'author.name() ++ " <" ++ author.email() ++ ">\n" ++ committer.name() ++ " <" ++ committer.email() ++ ">\n" ++ description ++ "\n"'
  jj_log -r "$revs" --git -T '' | sed -n -e '/^+++ /d' -e '/^+/p'
} | in_git git-gitleaks-scan --stdin; then
  echo "jj push: gitleaks flagged a commit above." >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  echo "jj push: nothing pushed." >&2
  exit 1
fi
# Not exec: the EXIT trap still has to remove $msg.
jj git push "$@"
