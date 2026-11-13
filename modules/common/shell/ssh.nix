# modules/common/shell/ssh.nix
#
# The SSH client. Each host connects and signs with its own ~/.ssh/id_ed25519
# (ssh-enroll creates and registers it); config/ssh/config picks that key for
# personal hosts and reads ~/.ssh/config.local first for machine overrides.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.shell.ssh.enable = lib.mkEnableOption "SSH client configuration";
  config = lib.mkIf config.modules.shell.ssh.enable {
    hm = hm: {
      home.packages = [
        pkgs.openssh
        pkgs.ssh-enroll
      ];
      # ssh refuses keys in a directory others can read. Runs before the
      # config link would create ~/.ssh with default permissions.
      home.activation.sshDirectory =
        hm.lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            run mkdir -p "$HOME/.ssh"
            run chmod 700 "$HOME/.ssh"
          '';
    };
    modules.dotfiles.homeLink.".ssh/config" = "ssh/config";
  };
}
