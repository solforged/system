HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
KEYTIMEOUT=10

mkdir -p "${HISTFILE:h}"

setopt autocd
setopt completeinword
setopt extendedglob
setopt globcomplete
setopt histignorealldups
setopt histignorespace
setopt incappendhistory
setopt interactivecomments
setopt magicequalsubst
setopt sharehistory
setopt histfindnodups
setopt histreduceblanks
setopt histverify

unsetopt beep
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=50
HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE=1

zstyle ':completion::complete:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*' completer _expand _complete _ignored
zstyle ':completion:*:expand:*' tag-order all-expansions
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
[[ -n "${LS_COLORS:-}" ]] && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':fzf-tab:*' switch-group '<' '>'
