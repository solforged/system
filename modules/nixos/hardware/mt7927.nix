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

    # The flake builds with plain `make`, so its modules lack the kmodigest
    # .ko.cer files nixpkgs' aggregateModules concatenates into modules.cer,
    # and the modules tree fails to build. Sign them after fixup, since
    # stripping changes the digest. Otherwise as in nixos kernel.nix.
    system.modulesTree = lib.mkForce (
      [ (lib.getOutput "modules" config.boot.kernelPackages.kernel) ]
      ++ map (
        pkg:
        if lib.hasPrefix "mediatek-mt7927-" (pkg.pname or "") then
          pkg.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              find "$out/lib/modules" -name '*.ko' -exec ${lib.getExe pkgs.kmodigest} {} \;
            '';
          })
        else
          pkg
      ) config.boot.extraModulePackages
    );
  };
}
