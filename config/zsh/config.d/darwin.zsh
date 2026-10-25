# macOS-only helpers. Formulae and casks are declared in modules/darwin and
# the host files, so there are no install or uninstall aliases.
[[ $OSTYPE == darwin* ]] || return 0

alias b='brew'
alias bs='brew search'
