# modules/nixos/agents/hermes-sandbox.nix
#
# What Hermes' Docker terminal backend mounts into its rootless Podman
# sandbox, so the agent can run unattended without the rest of the home
# directory. Hermes creates and reuses the container itself; config.yaml lists
# the mounts (README, "Hermes sandbox").
#
# - ~/.local/share/hermes-sandbox/nix becomes the container's /nix: a store of
#   its own, seeded with Nix and mise. Sharing the host daemon instead would
#   hand the agent root, since the user is a trusted Nix user.
# - ~/.local/share/hermes-sandbox/profile.sh becomes an /etc/profile.d entry.
#   Hermes snapshots a login shell, so this is where PATH and git's signing
#   config reach the agent.
# - $XDG_RUNTIME_DIR/hermes-ssh-agent holds a second Proton Pass agent that
#   serves only the Hermes vault. Its key signs commits and opens no logins.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.agents.hermes.sandbox;
  home = config.users.users.${config.user.name}.home;
  root = "${home}/.local/share/hermes-sandbox";
  vault = "Hermes";
  agentSocket = "/mnt/hermes-ssh-agent/agent.sock";

  common = import ../../common/shell/vcs/_common.nix { inherit config lib pkgs; };
  signingKey = config.user.agentSigningKeys."hermes-${config.networking.hostName}" or null;
  sign = signingKey != null;

  # Paths below resolve inside the container, where the seeded store is /nix.
  profileDir = "/nix/var/nix/profiles/hermes";

  gitconfig = pkgs.writeTextDir "etc/gitconfig" (
    lib.generators.toGitINI (
      {
        user = {
          inherit (common) name email;
        }
        // lib.optionalAttrs sign { signingkey = "key::${signingKey}"; };
      }
      // lib.optionalAttrs sign {
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile = "${common.allowedSigners}";
        };
        commit.gpgsign = true;
        tag.gpgsign = true;
      }
    )
  );

  # The container is unprivileged: no build users, no build sandbox.
  nixConf = pkgs.writeTextDir "etc/nix/nix.conf" ''
    experimental-features = nix-command flakes
    build-users-group =
    sandbox = false
  '';

  profile = pkgs.writeTextDir "etc/profile.d/hermes-sandbox.sh" (
    ''
      export PATH="''${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:${profileDir}/bin:$PATH"
      export NIX_CONF_DIR=${profileDir}/etc/nix
      export GIT_CONFIG_SYSTEM=${profileDir}/etc/gitconfig
      export LLM_WIKI_DIR=${home}/wiki
    ''
    + lib.optionalString sign ''
      export SSH_AUTH_SOCK=${agentSocket}
    ''
  );

  tools = pkgs.buildEnv {
    name = "hermes-sandbox-tools";
    paths = [
      config.nix.package
      pkgs.mise
      gitconfig
      nixConf
      profile
    ];
  };

  # Mounted as a file, so its content stays fixed; the profile it sources moves.
  entry = pkgs.writeText "hermes-sandbox-entry.sh" ''
    . ${profileDir}/etc/profile.d/hermes-sandbox.sh
  '';

  seed = pkgs.writeShellApplication {
    name = "hermes-sandbox-seed";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
    ];
    text = ''
      root=${lib.escapeShellArg root}
      nix copy --no-check-sigs --to "local?root=$root" ${tools}
      profiles=$root/nix/var/nix/profiles
      mkdir -p "$profiles" "$root/nix/var/nix/gcroots"
      ln -sfn /nix/var/nix/profiles "$root/nix/var/nix/gcroots/profiles"
      ln -sfn ${tools} "$profiles/hermes.new"
      mv -T "$profiles/hermes.new" "$profiles/hermes"
      install -m 644 ${entry} "$root/profile.sh"
    '';
  };
in
{
  options.modules.agents.hermes.sandbox.enable =
    lib.mkEnableOption "the Podman sandbox Hermes runs its tools in";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.agents.hermes.enable && config.modules.virt.containers.enable;
        message = "modules.agents.hermes.sandbox needs modules.agents.hermes and modules.virt.containers.";
      }
      {
        assertion = !sign || config.modules.apps.proton-pass.enable;
        message = "Hermes' signing key lives in Proton Pass; enable modules.apps.proton-pass.";
      }
    ];

    hm.systemd.user.services = {
      hermes-sandbox-store = {
        Unit.Description = "Nix store for the Hermes sandbox";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe seed;
        };
        Install.WantedBy = [ "default.target" ];
      };

      hermes-ssh-agent = lib.mkIf sign {
        Unit.Description = "Proton Pass SSH agent for the Hermes sandbox (${vault} vault only)";
        Service = {
          Environment = [ "PROTON_PASS_LINUX_KEYRING=dbus" ];
          # The container binds this directory; keep it, and its inode, across restarts.
          RuntimeDirectory = "hermes-ssh-agent";
          RuntimeDirectoryMode = "0700";
          RuntimeDirectoryPreserve = "yes";
          ExecStartPre = "${pkgs.coreutils}/bin/rm -f %t/hermes-ssh-agent/agent.sock";
          ExecStart = "${lib.getExe' pkgs.proton-pass-cli "pass-cli"} ssh-agent start --vault-name ${vault} --socket-path %t/hermes-ssh-agent/agent.sock";
          # Fails until `pass-cli login` has run on this host.
          Restart = "on-failure";
          RestartSec = 30;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
