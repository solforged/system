# Secret-scan every commit: the staged diff on pre-commit, the message on
# commit-msg (--commit-msg FILE), and on --stdin whatever jj push pipes in.
# modules/common/shell/vcs/_common.nix sets policy_file, allowlist_file and
# work_remote_file ahead of this script.
work_remote_regex="$(cat "$work_remote_file" 2>/dev/null || true)"

tmp=""
input=""
cleanup() {
  if [ -n "$tmp" ]; then
    rm -f "$tmp"
  fi
  if [ -n "$input" ]; then
    rm -f "$input"
  fi
}
trap cleanup EXIT

hook="pre-commit"
msg_file=""
case "${1:-}" in
  --commit-msg)
    hook="commit-msg"
    msg_file="${2:-$(git rev-parse --git-path COMMIT_EDITMSG)}"
    ;;
  --stdin)
    # Kept in a file: the policy and repo-local scans each read it.
    hook="push"
    input="$(mktemp "${TMPDIR:-/tmp}/gitleaks-input.XXXXXX")"
    cat >"$input"
    ;;
esac

# Replaying an unchanged historical message must not make a new global policy
# retroactively reject a rebase. Any reword still goes through the scanner.
if [ -n "$msg_file" ] && [ -f "$msg_file" ]; then
  rebase_head="$(git rev-parse -q --verify 'REBASE_HEAD^{commit}' 2>/dev/null || true)"
  message="$(sed -e '/^#.*>8/,$d' -e '/^#/d' "$msg_file" | git stripspace)"
  if [ -n "$rebase_head" ]; then
    rebase_message="$(git log -1 --format=%B "$rebase_head" | git stripspace)"
    if [ "$message" = "$rebase_message" ]; then
      exit 0
    fi
  fi
fi

# Leftover shell exports must not choose the config; scans pass -c or defaults.
unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML

scan() {
  if [ -n "$input" ]; then
    gitleaks stdin --redact --no-banner "$@" <"$input"
  elif [ -n "$msg_file" ]; then
    [ -f "$msg_file" ] || return 0
    sed -e '/^#.*>8/,$d' -e '/^#/d' "$msg_file" |
      gitleaks stdin --redact --no-banner "$@"
  else
    gitleaks git --staged --redact --no-banner "$@"
  fi
}

require_file() {
  if [ ! -s "$1" ]; then
    echo "$hook: missing $1, refusing to continue." >&2
    echo "$hook: agenix decrypts it on switch; check age.identityPaths." >&2
    exit 1
  fi
}

toplevel="$(git rev-parse --show-toplevel 2>/dev/null || true)"

# Detect work repositories by origin URL. The pattern that names the internal
# forges is secrets/gitleaks-work-remote.age, never committed in plaintext,
# because this script is published. No pattern means no repository is a work
# repository. Work repos skip the identity denylist
# (internal vocabulary is legitimate there) and use only gitleaks built-in
# detection, plus any repo-local .gitleaks.toml.
is_work_repo=0
if [ -n "$toplevel" ] && [ -n "$work_remote_regex" ]; then
  remote_url="$(git -C "$toplevel" remote get-url origin 2>/dev/null || true)"
  if [ -n "$remote_url" ] &&
    printf '%s\n' "$remote_url" | grep -qiE "$work_remote_regex"; then
    is_work_repo=1
  fi
fi

# Personal repos: the identity policy is mandatory. Work repos skip it.
if [ "$is_work_repo" -eq 0 ]; then
  require_file "$policy_file"
  config_file="$policy_file"

  # A repository with no remote on a public forge cannot publish work
  # vocabulary, and there those words are ordinary working vocabulary, so the
  # allowlist relaxes them. It covers only the work terms; the personal-name
  # rule has no exemption anywhere. A repository that gains a public remote is
  # strict again from its next commit.
  if ! git remote -v 2>/dev/null |
    grep -qiE '(github|gitlab)\.com|bitbucket\.org|codeberg\.org|git\.sr\.ht'; then
    require_file "$allowlist_file"
    tmp="$(mktemp "${TMPDIR:-/tmp}/gitleaks.XXXXXX")"
    cat "$policy_file" "$allowlist_file" >"$tmp"
    config_file="$tmp"
  fi

  # The staged diff cannot reveal who is committing: author and committer are
  # not part of it, so no content rule can ever match them. That blind spot is
  # what lets a work identity reach a repository whose remote can publish it,
  # because git resolves identity by includeIf on the remote URL while this
  # policy is chosen by the same URL a step later. Resolve the full chain and
  # scan it as ordinary text. jj push puts the identities in its input.
  if [ -z "$msg_file" ] && [ -z "$input" ]; then
    if ! { git var GIT_AUTHOR_IDENT; git var GIT_COMMITTER_IDENT; } |
      gitleaks stdin --redact --no-banner -c "$config_file" >/dev/null 2>&1; then
      echo "$hook: commit identity violates the identifier policy." >&2
      echo "$hook: locate it with: git config --show-origin --get user.email" >&2
      exit 1
    fi
  fi
  scan -c "$config_file"
fi

# Repo-local policy runs as an additive second scan in every repo.
# Work repos without a repo-local config still get a bare defaults scan.
if [ -n "$toplevel" ] && [ -f "$toplevel/.gitleaks.toml" ]; then
  scan -c "$toplevel/.gitleaks.toml"
elif [ "$is_work_repo" -eq 1 ]; then
  scan
fi
