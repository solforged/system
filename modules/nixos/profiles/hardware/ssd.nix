# modules/nixos/profiles/hardware/ssd.nix
{ config, lib, ... }:

{
  config = lib.mkIf (lib.elem "ssd" config.modules.profiles.hardware) {
    services.fstrim.enable = true;
  };
}
