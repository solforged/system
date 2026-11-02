# modules/nixos/env.nix
#
# PAM sets session variables for every login, so GNOME apps see them too.
# NixOS rewrites $HOME for PAM.
{ config, lib, ... }:

{
  environment.sessionVariables = config.modules.env.variables;

  # /etc/zshenv loads this environment before the terminal's .zshenv.
  # Preserve its shell-integration directory; PAM still gets our usual path.
  environment.variables.ZDOTDIR = lib.mkIf config.modules.shell.zsh.enable (
    lib.mkForce "\${ZDOTDIR-$HOME/.config/zsh}"
  );
}
