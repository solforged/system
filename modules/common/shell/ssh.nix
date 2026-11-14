# modules/common/shell/ssh.nix
#
# The SSH client. GitHub and personal hosts take the YubiKeys' FIDO2 keys:
# this host's handle for the primary (ssh-enroll) and, once pulled, the
# backup's (see docs/secrets.md). config/ssh/config picks them and reads
# ~/.ssh/config.local first for machine overrides. Host keys of GitHub and of
# the hosts that accept SSH are pinned system-wide.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  hostKeys = import ../../../secrets/host-keys.nix;
  # Hosts move to the passkey-owned tailnet individually.
  tailnets = {
    amarna = "ussuri-alphard.ts.net";
    hyperion = "ostrich-rigel.ts.net";
  };

  # From https://api.github.com/meta (ssh_keys).
  github = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
  ];

  personal = host: {
    hostNames = [
      host
      "${host}.${tailnets.${host}}"
    ];
    publicKey = hostKeys.${host};
  };
in
{
  options.modules.shell.ssh.enable = lib.mkEnableOption "SSH client configuration";
  config = lib.mkIf config.modules.shell.ssh.enable {
    programs.ssh.knownHosts = {
      amarna = personal "amarna";
      hyperion = personal "hyperion";
    }
    // lib.listToAttrs (
      lib.imap0 (i: key: {
        name = "github.com-${toString i}";
        value = {
          hostNames = [ "github.com" ];
          publicKey = key;
        };
      }) github
    );

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
