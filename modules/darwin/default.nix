# modules/darwin/default.nix
#
# Core settings for every nix-darwin host.
{ config, lib, ... }:

let
  user = config.user.name;
in
{
  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";

  security.pam.services.sudo_local.touchIdAuth = true;

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      options = "--delete-older-than 14d";
    };
  };
}
