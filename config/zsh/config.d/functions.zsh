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

# --- Git worktrees ---
# Canonical repo key, independent of the current subdirectory or worktree.
ga() {
  [[ $# == 1 ]] || { print -u2 'Usage: ga <branch>'; return 1; }
  local common base branch="$1" slug root target
  git check-ref-format --branch "$branch" >/dev/null || return 1
  common=$(git rev-parse --path-format=absolute --git-common-dir) || return 1
  common=$(cd "$common" && pwd -P) || return 1
  base="${common%/.git}"
  base="${base:t}"
  slug="${branch//\//-}"
  root="${OMP_WORKTREE_DIR:-$HOME/.omp/wt}"
  [[ "$root" == /* ]] || { print -u2 'OMP_WORKTREE_DIR must be absolute'; return 1; }
  target="$root/$base--$slug"
  [[ ! -e "$target" && ! -L "$target" ]] || { print -u2 "Path already exists: $target"; return 1; }
  mkdir -p "$root" || return 1
  git worktree add -b "$branch" "$target" || return 1
  cd "$target"
}

# Refuse main checkouts and dirty trees; never force-delete a branch.
gd() {
  local common git_dir top main branch confirm=n
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
