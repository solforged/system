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
  environment.variables = config.modules.env.variables;
  launchd.user.envVariables = lib.mapAttrs (
    _: lib.replaceStrings [ "$HOME" ] [ home ]
  ) config.modules.env.variables;
}
