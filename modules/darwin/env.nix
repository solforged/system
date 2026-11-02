# modules/darwin/env.nix
#
# Shells get the variables from /etc/zshenv. launchd gets them too, so apps
# started from the Dock or Finder agree with the shell; launchd does no
# expansion, so $HOME is resolved here.
{ config, lib, ... }:

let
  home = config.users.users.${config.user.name}.home;
in
{
  environment.variables = lib.mkMerge [
    config.modules.env.variables
    # /etc/zshenv runs before the terminal's .zshenv. Keep the ZDOTDIR a
    # terminal points at its shell-integration directory (Tern, Ghostty);
    # launchd still hands every app our usual path.
    (lib.mkIf config.modules.shell.zsh.enable {
      ZDOTDIR = lib.mkForce "\${ZDOTDIR-$HOME/.config/zsh}";
    })
  ];
  launchd.user.envVariables = lib.mapAttrs (
    _: lib.replaceStrings [ "$HOME" ] [ home ]
  ) config.modules.env.variables;
}
