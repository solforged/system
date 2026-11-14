md() {
  mkdir -p "$1" && cd "$1"
}

if (( $+commands[omp] )); then
  # omp commit uses its own prompt and will not read AGENTS.md. Inject the
  # global commit-msg policy unless the caller already passed --context.
  # OMP_LAUNCHER names a wrapper to run instead of omp, such as a sandbox.
  omp() {
    local bin=${OMP_LAUNCHER:-omp}
    if [[ "$1" == "commit" ]]; then
      shift
      local skip=0 arg
      for arg in "$@"; do
        case "$arg" in
          --context|-c|--help|-h) skip=1; break ;;
        esac
      done
      if (( skip )); then
        command "$bin" commit "$@"
      else
        local policy="${XDG_CONFIG_HOME:-$HOME/.config}/git/commit-style.md"
        [[ -r "$policy" ]] || { print -u2 "Missing commit policy: $policy"; return 1; }
        command "$bin" commit --context "$(< "$policy")" "$@"
      fi
    else
      command "$bin" "$@"
    fi
  }
fi

path_prepend() {
  [[ -d "$1" ]] && path=("$1" $path)
}

y() {
  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]] && builtin cd -- "$cwd"
  command rm -f "$tmp"
}

# Open nvim on the current directory, or on the given files.
n() {
  if (( $# == 0 )); then
    command nvim .
  else
    command nvim "$@"
  fi
}

# Fuzzy-find a file with a preview; eff opens the pick in $EDITOR.
alias ff="fzf --preview 'bat --style=numbers --color=always --theme=ansi --paging=never -- {}'"
eff() {
  local selected
  selected=$(ff "$@") || return
  [[ -n "$selected" ]] || return
  local -a editor=( ${(z)${EDITOR:-ms}} )
  "${(@Q)editor}" -- "$selected"
}

compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }

# --- Listing (eza) ---
if command -v eza >/dev/null 2>&1; then
  unalias ls ll la lt lta 2>/dev/null
  _eza_defaults=(--color=auto --group-directories-first --classify=auto)
  _eza_long_defaults=(-l --time-style=long-iso)

  # The whole if block is parsed before unalias runs, so avoid alias expansion.
  function ls { command eza "${_eza_defaults[@]}" "$@"; }
  function ll { command eza "${_eza_defaults[@]}" "${_eza_long_defaults[@]}" "$@"; }
  function la { 'll' -a "$@"; }
  function lt { command eza "${_eza_defaults[@]}" -l --time-style=long-iso --tree --level=2 --icons --git "$@"; }
  function lta { 'lt' -a "$@"; }
fi

# --- Workspaces and worktrees ---
# ${PI_WORKTREE_DIR:-~/.pi/wt}/<repo>--<name>, the root Pi's /wt uses: a jj
# workspace in a jj repository, a worktree and branch in a Git-only one. The
# repo key is independent of the current subdirectory or checkout.
ga() {
  [[ $# == 1 ]] || { print -u2 'Usage: ga <name>'; return 1; }
  local common base name="$1" slug root target
  root="${PI_WORKTREE_DIR:-$HOME/.pi/wt}"
  [[ "$root" == /* ]] || { print -u2 'PI_WORKTREE_DIR must be absolute'; return 1; }
  slug="${name//\//-}"
  if jj root >/dev/null 2>&1; then
    [[ -n "$name" && "$name" != *[[:space:]]* ]] || { print -u2 "Invalid workspace name: $name"; return 1; }
    base=$(jj workspace root --name default) || return 1
    base="${base:t}"
  else
    git check-ref-format --branch "$name" >/dev/null || return 1
    common=$(git rev-parse --path-format=absolute --git-common-dir) || return 1
    common=$(cd "$common" && pwd -P) || return 1
    base="${common%/.git}"
    base="${base:t}"
  fi
  target="$root/$base--$slug"
  [[ ! -e "$target" && ! -L "$target" ]] || { print -u2 "Path already exists: $target"; return 1; }
  mkdir -p "$root" || return 1
  if jj root >/dev/null 2>&1; then
    jj workspace add --name "$slug" "$target" || return 1
  else
    git worktree add -b "$name" "$target" || return 1
  fi
  cd "$target"
}

# Refuse the main checkout and uncommitted changes; never force-delete a branch.
gd() {
  local common git_dir top main branch name confirm=n
  if jj root >/dev/null 2>&1; then
    top=$(jj workspace root) || return 1
    main=$(jj workspace root --name default) || return 1
    [[ "$top" != "$main" ]] || { print -u2 'Not a linked workspace'; return 1; }
    name=$(jj workspace list -T 'name ++ "\t" ++ root ++ "\n"' | awk -F '\t' -v top="$top" '$2 == top { print $1 }')
    [[ -n "$name" ]] || return 1
    [[ "$(jj log -r @ --no-graph -T empty)" == true ]] || {
      print -u2 'The working copy has changes; commit, squash or abandon them first'
      return 1
    }
    if command -v gum >/dev/null 2>&1; then
      gum confirm "Remove $top and workspace $name?" || return 0
    else
      read -r "confirm?Remove $top and workspace $name? (y/N): "
      [[ "$confirm" != [Yy] ]] && return 0
    fi
    cd "$main" || return 1
    jj workspace forget "$name" || return 1
    rm -rf -- "$top"
    return
  fi
  common=$(git rev-parse --path-format=absolute --git-common-dir) || return 1
  git_dir=$(git rev-parse --path-format=absolute --git-dir) || return 1
  top=$(git rev-parse --show-toplevel) || return 1
  [[ "$git_dir" != "$common" ]] || { print -u2 'Not a linked worktree'; return 1; }
  main=$(git worktree list --porcelain | head -1)
  main="${main#worktree }"
  branch=$(git branch --show-current) || return 1
  if command -v gum >/dev/null 2>&1; then
    gum confirm "Remove $top and branch $branch?" || return 0
  else
    read -r "confirm?Remove $top and branch $branch? (y/N): "
    [[ "$confirm" != [Yy] ]] && return 0
  fi
  cd "$main" || return 1
  git worktree remove "$top" || return 1
  if [[ -n "$branch" ]]; then git branch -d "$branch"; fi
}
