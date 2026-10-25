# modules/darwin/virt/containers.nix
#
# Apple's `container`. `container system start` registers its API server with
# launchd using the resolved store path of the binary, so it runs again at
# every login: after an update, the registration follows the new store path
# instead of pointing at one that garbage collection may remove.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.virt.containers;
  home = config.users.users.${config.user.name}.home;
in
{
  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.container ];

    launchd.user.agents.container-system.serviceConfig = {
      ProgramArguments = [
        "${pkgs.container}/bin/container"
        "system"
        "start"
        "--enable-kernel-install"
      ];
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/container-system.log";
      StandardErrorPath = "${home}/Library/Logs/container-system.log";
    };
  };
}
