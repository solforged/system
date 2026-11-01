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
      # powerManagement preserves VRAM across suspend. Without a file path the
      # driver copies it into RAM, and a model filling VRAM OOM-kills the
      # session before suspend aborts. /var/tmp is disk-backed.
      moduleParams.nvidia.NVreg_TemporaryFilePath = "/var/tmp";
    };
  };
}
