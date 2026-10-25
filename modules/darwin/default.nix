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

  # Determinate Nix runs the daemon and garbage-collects on its own schedule
  # (determinate-nixd keeps 5-20% of the disk free). nix-darwin's nix.* options
  # are off; settings go to /etc/nix/nix.custom.conf.
  determinateNix = {
    enable = true;
    customSettings = {
      trusted-users = [
        "root"
        user
      ];
      warn-dirty = false;
    };
  };

  # nix.optimise needs nix.enable. auto-optimise-store is unsafe on macOS, so
  # hard-link the store weekly instead.
  launchd.daemons.nix-optimise = {
    command = "/nix/var/nix/profiles/default/bin/nix-store --optimise";
    serviceConfig = {
      RunAtLoad = false;
      StartCalendarInterval = [
        {
          Weekday = 7;
          Hour = 4;
          Minute = 15;
        }
      ];
    };
  };
}
