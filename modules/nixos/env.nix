# modules/nixos/env.nix
#
# PAM sets session variables for every login, so GNOME apps see them too.
# NixOS rewrites $HOME for PAM.
{ config, ... }:

{
  environment.sessionVariables = config.modules.env.variables;
}
