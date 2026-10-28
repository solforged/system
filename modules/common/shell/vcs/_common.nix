# modules/common/shell/vcs/_common.nix
#
# The identity and check scripts git.nix and jj.nix share. Not a module: the
# leading "_" keeps the module walker from importing it.
{
  config,
  lib,
  pkgs,
}:

let
  cfg = config.modules.shell.vcs;
  secrets = config.age.secrets;
in
rec {
  name = "solforged";
  email = "sol@sowilo.io";

  # Proton Pass keys, served by its SSH agent. Each host signs with its own.
  signingKey = config.user.sshKeys.${config.networking.hostName} or null;
  sign = cfg.sign && signingKey != null;
  allowedSigners = pkgs.writeText "allowed_signers" (
    lib.concatMapStrings (key: "${email} ${key}\n") (lib.attrValues config.user.sshKeys)
  );

  stripCursorAttribution = pkgs.writeShellApplication {
    name = "git-strip-cursor-attribution";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gawk
    ];
    text = builtins.readFile ./strip-cursor-attribution.sh;
  };

  commitMessagePolicy = pkgs.writeShellApplication {
    name = "git-commit-message-policy";
    runtimeInputs = with pkgs; [
      gawk
      git
    ];
    text = builtins.readFile ./commit-message-policy.sh;
  };

  gitleaksScan = pkgs.writeShellApplication {
    name = "git-gitleaks-scan";
    runtimeInputs = with pkgs; [
      coreutils
      git
      gitleaks
      gnugrep
      gnused
    ];
    text = ''
      policy_file=${secrets.gitleaks-policy.path}
      allowlist_file=${secrets.gitleaks-allowlist.path}
      work_remote_file=${secrets.gitleaks-work-remote.path}
    ''
    + builtins.readFile ./gitleaks.sh;
  };
}
