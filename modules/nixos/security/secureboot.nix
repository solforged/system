{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.security.secureboot;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];
  options.modules.security.secureboot = {
    enable = lib.mkEnableOption "Secure Boot administration tools";
    sign = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Sign boot artifacts with the existing sbctl keys. Before enabling,
        restore /var/lib/sbctl (including GUID and keys) with root-only key
        permissions. Keep this false for the first installation, with firmware
        Secure Boot temporarily disabled, without clearing enrolled keys.
        Enable signing, rebuild with --install-bootloader, run sbctl verify,
        then re-enable firmware Secure Boot. Existing enrolled keys need no
        enrollment. If firmware keys were reset, enter Setup Mode and enroll
        with sbctl enroll-keys --microsoft --tpm-eventlog before re-enabling.
        Keep a LUKS recovery passphrase. PCR-bound TPM tokens may need resealing.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sbctl ];
    boot.loader.systemd-boot.enable = lib.mkIf cfg.sign (lib.mkForce false);
    boot.lanzaboote = lib.mkIf cfg.sign {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };
}
