# The same prompt as config/nushell/config.nu draws outside Tern's native
# prompt: a blank line, host, directory and git state, then `>` on the input
# line, green or red by the last status, and `<` in vi command mode. The
# right side shows the last command's duration from 2 seconds and a failing
# status. Inside Tern, its zsh integration takes the prompt over.

autoload -Uz add-zsh-hook
zmodload zsh/datetime
setopt prompt_subst

# `[branch status]`: the branch, or `@hash` when detached; one symbol per kind
# of change; ahead, behind or diverged from upstream; a rebase, merge or other
# operation in progress.
_prompt_git() {
  _prompt_git_info=
  local gitdir out line head oid x y state cur total
  local -i ahead=0 behind=0
  local -A seen
  gitdir=$(command git rev-parse --absolute-git-dir 2>/dev/null) || return
  out=$(command git --no-optional-locks status --porcelain=2 --branch 2>/dev/null) || return
  for line in ${(f)out}; do
    case $line in
      ('# branch.head '*) head=${line#'# branch.head '} ;;
      ('# branch.oid '*) oid=${line#'# branch.oid '} ;;
      ('# branch.ab '*)
        line=${line#'# branch.ab '}
        ahead=${${line%% *}#+}
        behind=${${line##* }#-}
        ;;
      ('u '*) seen[conflicted]=1 ;;
      ('? '*) seen[untracked]=1 ;;
      ([12]' '*)
        x=${line[3]} y=${line[4]}
        [[ $x != . ]] && seen[staged]=1
        [[ $x == R ]] && seen[renamed]=1
        [[ $x == D || $y == D ]] && seen[deleted]=1
        [[ $y == M ]] && seen[modified]=1
        [[ $x == T || $y == T ]] && seen[typechanged]=1
        ;;
    esac
  done

  local s=
  (( ${+seen[conflicted]} )) && s+='%B%F{red}=%b'
  (( ${+seen[deleted]} )) && s+='%F{red}✘'
  (( ${+seen[renamed]} )) && s+='%F{cyan}»'
  (( ${+seen[modified]} )) && s+='%F{yellow}!'
  (( ${+seen[typechanged]} )) && s+='%F{yellow}~'
  (( ${+seen[staged]} )) && s+='%F{green}+'
  (( ${+seen[untracked]} )) && s+='%F{yellow}?'
  if (( ahead && behind )); then
    s+='%F{yellow}⇕'
  elif (( ahead )); then
    s+='%F{blue}⇡'
  elif (( behind )); then
    s+='%F{yellow}⇣'
  fi
  [[ -n $s ]] && s=" $s"

  if [[ -d $gitdir/rebase-merge ]]; then
    state=REBASING
    cur=$(<$gitdir/rebase-merge/msgnum) total=$(<$gitdir/rebase-merge/end)
  elif [[ -d $gitdir/rebase-apply ]]; then
    if [[ -e $gitdir/rebase-apply/rebasing ]]; then
      state=REBASING
    elif [[ -e $gitdir/rebase-apply/applying ]]; then
      state=AM
    else
      state=AM/REBASE
    fi
    cur=$(<$gitdir/rebase-apply/next) total=$(<$gitdir/rebase-apply/last)
  elif [[ -e $gitdir/MERGE_HEAD ]]; then
    state=MERGING
  elif [[ -e $gitdir/REVERT_HEAD ]]; then
    state=REVERTING
  elif [[ -e $gitdir/CHERRY_PICK_HEAD ]]; then
    state=CHERRY-PICKING
  elif [[ -e $gitdir/BISECT_LOG ]]; then
    state=BISECTING
  fi 2>/dev/null
  if [[ -n $state ]]; then
    [[ -n $cur && -n $total ]] && state+=" $cur/$total"
    state=" %B%F{yellow}|$state%b"
  fi

  local name
  if [[ $head == '(detached)' ]]; then
    name="%F{yellow}@${oid[1,7]}"
  else
    name="%F{blue}${head//\%/%%}"
  fi
  _prompt_git_info="%F{blue}[$name$s$state%F{blue}]%f "
}

_prompt_char() {
  if [[ $1 == vicmd ]]; then
    _prompt_vi='%B%F{green}<%f%b'
  elif (( _prompt_status )); then
    _prompt_vi='%B%F{red}>%f%b'
  else
    _prompt_vi='%B%F{green}>%f%b'
  fi
}

_prompt_preexec() {
  _prompt_start=$EPOCHREALTIME
}

_prompt_precmd() {
  _prompt_status=$?
  _prompt_right=
  if [[ -n ${_prompt_start-} ]]; then
    local -i ms=$(( (EPOCHREALTIME - _prompt_start) * 1000 ))
    unset _prompt_start
    if (( ms >= 2000 )); then
      local -i s=$(( ms / 1000 ))
      local -i h=$(( s / 3600 )) m=$(( s % 3600 / 60 )) sec=$(( s % 60 ))
      if (( h )); then
        _prompt_right="%F{yellow}${h}h${m}m${sec}s%f"
      elif (( m )); then
        _prompt_right="%F{yellow}${m}m${sec}s%f"
      else
        _prompt_right="%F{yellow}${sec}s%f"
      fi
    fi
  fi
  if (( _prompt_status )); then
    _prompt_right+="${_prompt_right:+ }%F{red}${_prompt_status}%f"
  fi
  _prompt_char viins
  _prompt_git
}

# Redraws `>` as `<` and back when the vi keymap changes.
_prompt_keymap() {
  _prompt_char $KEYMAP
  zle reset-prompt
}

add-zsh-hook preexec _prompt_preexec
precmd_functions=(_prompt_precmd $precmd_functions)
zle -N zle-keymap-select _prompt_keymap

PROMPT=$'\n%F{8}%m%f %F{blue}%(4~|…/%3~|%~)%f ${_prompt_git_info}\n${_prompt_vi} '
RPROMPT='${_prompt_right}'
PROMPT2='%F{8}∙%f '
