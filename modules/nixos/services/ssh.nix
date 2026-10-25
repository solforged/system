# modules/nixos/services/ssh.nix
{ config, lib, ... }:

let
  cfg = config.modules.services.ssh;
in
{
  options.modules.services.ssh.enable = lib.mkEnableOption "OpenSSH server";

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
