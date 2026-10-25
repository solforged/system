alias grep='grep --color=auto'

alias e='nvim'
alias gg='lazygit'

alias cdd="cd $DOTFILES_DIR"
alias cdw="cd $LLM_WIKI_DIR"

alias eal="cd $DOTFILES_DIR && $EDITOR $DOTFILES_DIR/config/zsh/config.d/aliases.zsh"

alias gl="glow -t"

command -v omp &>/dev/null && alias omr='omp --resume'

hash -d df="$DOTFILES_DIR"
hash -d an="$HOME/work/analysis"
hash -d lst="${XDG_STATE_HOME:-$HOME/.local/state}"
hash -d lsh="${XDG_DATA_HOME:-$HOME/.local/share}"

alias ..='cd ..'
alias ...='cd ../..'
alias decompress="tar -xzf"

alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

command -v docker &>/dev/null && alias d='docker'
command -v claude &>/dev/null && alias cx='printf "\033[2J\033[3J\033[H" && claude --permission-mode auto'
alias mup='MISE_MINIMUM_RELEASE_AGE=0 mise up'
