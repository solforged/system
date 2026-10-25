{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.hardware.mt7927;
in
{
  imports = [ inputs.mt7927.nixosModules.default ];
  options.modules.hardware.mt7927.enable =
    lib.mkEnableOption "MediaTek MT7927 Wi-Fi and MT6639 Bluetooth";
  config = lib.mkIf cfg.enable {
    # Keep the kernel ABI aligned with the driver's pinned 7.2 sources.
    boot.kernelPackages = pkgs.linuxPackages_7_2;
    hardware.mediatek-mt7927 = {
      enable = true;
      enableWifi = true;
      enableBluetooth = true;
      disableAspm = true;
    };
  };
}
