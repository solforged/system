# Shell options, functions, and aliases
[[ -r "$ZDOTDIR/config.d/options.zsh" ]] && source "$ZDOTDIR/config.d/options.zsh"
[[ -r "$ZDOTDIR/config.d/functions.zsh" ]] && source "$ZDOTDIR/config.d/functions.zsh"
[[ -r "$ZDOTDIR/config.d/ssh.zsh" ]] && source "$ZDOTDIR/config.d/ssh.zsh"
[[ -r "$ZDOTDIR/config.d/linux.zsh" ]] && source "$ZDOTDIR/config.d/linux.zsh"
[[ -r "$ZDOTDIR/config.d/darwin.zsh" ]] && source "$ZDOTDIR/config.d/darwin.zsh"
[[ -r "$ZDOTDIR/config.d/aliases.zsh" ]] && source "$ZDOTDIR/config.d/aliases.zsh"

# Completion, plugins, and history search are generated in the store.
_zsh_plugins="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins.zsh"
[[ -r "$_zsh_plugins" ]] && source "$_zsh_plugins"
unset _zsh_plugins

# Keybindings follow Atuin's widgets.
[[ -r "$ZDOTDIR/config.d/keybinds.zsh" ]] && source "$ZDOTDIR/config.d/keybinds.zsh"

# Prompt, environment, secrets, and directory navigation.
_zsh_init="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/init.zsh"
[[ -r "$_zsh_init" ]] && source "$_zsh_init"
unset _zsh_init
