# modules/nixos/apps/claude-desktop.nix
#
# Cowork runs its tasks in a QEMU VM. The app looks for QEMU on PATH, but for
# UEFI firmware and virtiofsd only at Debian's fixed paths, so link the Nix
# builds there.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.apps.claude-desktop;
in
{
  options.modules.apps.claude-desktop.cowork.enable =
    lib.mkEnableOption "Cowork, which runs Claude's agent tasks in a local QEMU VM";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hm.home.packages = [ pkgs.claude-desktop ];

        # The app keeps its sign-in in the Secret Service.
        services.gnome.gnome-keyring.enable = true;
      }

      (lib.mkIf cfg.cowork.enable {
        hm.home.packages = [ pkgs.qemu_kvm ];

        # The VM's vsock needs /dev/vhost-vsock, which only the kvm group opens.
        users.users.${config.user.name}.extraGroups = [ "kvm" ];
        boot.kernelModules = [ "vhost_vsock" ];

        # The app takes <prefix>_CODE.fd and derives <prefix>_VARS.fd beside it.
        systemd.tmpfiles.rules =
          let
            prefix = if pkgs.stdenv.hostPlatform.isAarch64 then "AAVMF" else "OVMF";
          in
          [
            "L+ /usr/share/${prefix} - - - - ${pkgs.OVMF.fd}/FV"
            "L+ /usr/libexec/virtiofsd - - - - ${lib.getExe pkgs.virtiofsd}"
          ];
      })
    ]
  );
}
