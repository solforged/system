# modules/nixos/profiles/hardware/gpu/nvidia.nix
{ config, lib, ... }:

{
  config = lib.mkIf (lib.elem "gpu/nvidia" config.modules.profiles.hardware) {
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # Blackwell (GB20x) only works with the open kernel modules.
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
  };
}
