# modules/darwin/services/ssh.nix
#
# Apple's sshd (Remote Login): keys only, only the keys Nix lists, and only
# from the tailnet. sshd keeps the first value it reads, and Apple's
# sshd_config includes sshd_config.d before its own settings, so these win.
{ config, lib, ... }:

let
  cfg = config.modules.services.ssh;
  user = config.user.name;
in
{
  options.modules.services.ssh.enable =
    lib.mkEnableOption "Remote Login, with keys from users.users.<name>.openssh.authorizedKeys, over Tailscale only";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.services.tailscale.enable;
        message = "modules.services.ssh accepts only tailnet addresses; enable modules.services.tailscale.";
      }
    ];

    services.openssh = {
      enable = true;
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
        AuthenticationMethods publickey
        # ~/.ssh/authorized_keys is ignored; nix-darwin's AuthorizedKeysCommand
        # serves the keys this flake declares.
        AuthorizedKeysFile none
        # Tailscale's IPv4 and IPv6 ranges.
        AllowUsers ${user}@100.64.0.0/10 ${user}@fd7a:115c:a1e0::/48
      '';
    };
  };
}
