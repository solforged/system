# modules/nixos/profiles/hardware/bluetooth.nix
{ config, lib, ... }:

{
  config = lib.mkIf (lib.elem "bluetooth" config.modules.profiles.hardware) {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
