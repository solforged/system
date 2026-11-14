# These assertions run during CI's drvPath evaluation, without building Linux
# on a Mac. Compilation and hardware testing remain separate checks.
{
  configuration,
  installer,
  inputs,
}:
let
  inherit (configuration) pkgs;
  inherit (pkgs) lib;
  driverSeries = lib.versions.majorMinor (builtins.fromJSON (
    builtins.readFile "${inputs.mt7927}/versions.json"
  )).mt76KVer;
  checkHost =
    name: host:
    let
      cfg = host.config;
      kernelSeries = lib.versions.majorMinor cfg.boot.kernelPackages.kernel.version;
      driver = cfg.hardware.mediatek-mt7927;
      packages = map (pkg: pkg.pname or "") cfg.boot.extraModulePackages;
    in
    assert lib.assertMsg (
      kernelSeries == driverSeries
    ) "${name}: MT7927 sources (${driverSeries}) must match the kernel series (${kernelSeries})";
    assert lib.assertMsg (
      driver.enable && driver.enableWifi && driver.enableBluetooth
    ) "${name}: MT7927 Wi-Fi and Bluetooth must remain enabled";
    assert lib.assertMsg (lib.all (name: lib.elem name packages) [
      "mediatek-mt7927-wifi"
      "mediatek-mt7927-bluetooth"
    ]) "${name}: both MT7927 kernel modules must remain installed";
    true;
in
assert lib.all lib.id (
  lib.mapAttrsToList checkHost {
    amarna = configuration;
    inherit installer;
  }
);
pkgs.runCommand "mt7927-kernel-check" { } ''
  touch "$out"
''
