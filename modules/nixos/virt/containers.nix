# modules/nixos/virt/containers.nix
#
# Rootless Podman. `docker` is an alias for podman, and DOCKER_HOST points
# Docker clients such as lazydocker and docker-compose at the user's Podman
# socket, so no root daemon runs.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.virt.containers;
in
{
  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    environment.extraInit = ''
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock"
    '';

    hm.home.packages = [ pkgs.docker-compose ];
  };
}
