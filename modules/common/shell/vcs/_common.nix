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

  # Each enrolled host signs with its own key, made by ssh-enroll, which can't
  # be copied off it and signs without a prompt. The type of the host's line in
  # user.signingKeys says where it lives:
  #
  # - sk-ecdsa: the Mac's Secure Enclave; ~/.ssh/id_ecdsa_sk_signing is a
  #   handle that Apple's provider, /usr/lib/ssh-keychain.dylib, signs with.
  # - ecdsa: the TPM; ~/.ssh/id_ecdsa_signing.tpm is sealed to it and served by
  #   ssh-tpm-agent, so Git names the public key.
  # - ssh-ed25519: a plain key file, ~/.ssh/id_ed25519, from before.
  #
  # Retired keys still verify old signatures; agent keys are trusted only for
  # Git's signature namespace.
  hostSigningKey = config.user.signingKeys.${config.networking.hostName} or null;
  signingKind =
    if hostSigningKey == null then
      null
    else if lib.hasPrefix "sk-ecdsa-sha2-nistp256@openssh.com " hostSigningKey then
      "enclave"
    else if lib.hasPrefix "ecdsa-sha2-nistp256 " hostSigningKey then
      "tpm"
    else
      "file";
  home = config.users.users.${config.user.name}.home;
  # null until ssh-enroll has run and the host's key is in user.signingKeys.
  signingKey =
    if signingKind == null then
      null
    else
      {
        enclave = "${home}/.ssh/id_ecdsa_sk_signing";
        tpm = "${home}/.ssh/id_ecdsa_signing.pub";
        file = "${home}/.ssh/id_ed25519";
      }
      .${signingKind};
  sign = cfg.sign && signingKey != null;

  # The ssh-keygen Git and jj sign and verify with, pointed at the key's home.
  signingProgram = pkgs.writeShellScript "ssh-keygen-signing" ''
    ${
      if pkgs.stdenv.hostPlatform.isDarwin then
        "export SSH_SK_PROVIDER=/usr/lib/ssh-keychain.dylib"
      else
        ''export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-tpm-agent.sock"''
    }
    exec ${lib.getExe' pkgs.openssh "ssh-keygen"} "$@"
  '';
  allowedSigners = pkgs.writeText "allowed_signers" (
    lib.concatMapStrings (key: "${email} ${key}\n") (
      lib.attrValues config.user.signingKeys ++ config.user.retiredSigningKeys
    )
    + lib.concatMapStrings (key: "${email} namespaces=\"git\" ${key}\n") (
      lib.attrValues config.user.agentSigningKeys
    )
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
