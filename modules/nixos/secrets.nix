# modules/nixos/secrets.nix
{ config, lib, ... }:

{
  # age-plugin-yubikey reaches the YubiKey's PIV applet through pcscd; macOS
  # has CryptoTokenKit built in.
  config = lib.mkIf config.modules.secrets.admin.enable {
    services.pcscd.enable = true;
  };
}
