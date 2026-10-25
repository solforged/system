{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.security.authentication;
in
{
  options.modules.security.authentication = {
    enable = lib.mkEnableOption "FIDO2 security keys and optional U2F login";
    fingerprint = lib.mkEnableOption "The USB fingerprint reader";
  };
  config = lib.mkIf cfg.enable {
    hm.home.packages = [
      pkgs.libfido2
      pkgs.pam_u2f
    ];
    security.pam.u2f = {
      enable = true;
      control = "sufficient";
      settings.cue = true;
    };
    services.fprintd.enable = cfg.fingerprint;
  };
}
