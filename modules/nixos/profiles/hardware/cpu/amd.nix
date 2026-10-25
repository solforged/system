# modules/nixos/profiles/hardware/cpu/amd.nix
{ config, lib, ... }:

{
  config = lib.mkIf (lib.elem "cpu/amd" config.modules.profiles.hardware) {
    hardware.cpu.amd.updateMicrocode = true;
    boot.kernelModules = [ "kvm-amd" ];
  };
}
