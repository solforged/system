# modules/common/secrets.nix
#
# agenix decrypts secrets/*.age at activation with this host's SSH host key.
# The key must exist and be listed in secrets/agenix-rules.nix before the first
# switch; on macOS, `sudo ssh-keygen -A` creates it without turning on Remote
# Login.
#
# Editing and rekeying need an admin identity: a PIV key on one of the two
# YubiKeys (PIN once per session, touch for every file), or the offline paper
# key. `secrets-edit <file>` and `secrets-rekey` ask the plugged-in YubiKeys
# for their identity stubs, which name a key and slot but hold nothing secret.
# SECRETS_IDENTITY=<file> uses that identity file instead.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.secrets;
  agenix = inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  withAdminKey =
    name: setup: agenixArgs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        agenix
        pkgs.age-plugin-yubikey
        pkgs.coreutils
      ];
      text = ''
        ${setup}
        if [ -n "''${SECRETS_IDENTITY:-}" ]; then
          identity=$SECRETS_IDENTITY
        else
          identity=$(mktemp)
          trap 'rm -f "$identity"' EXIT
          if ! age-plugin-yubikey --identity >"$identity" 2>/dev/null || ! [ -s "$identity" ]; then
            echo "${name}: plug in an admin YubiKey, or set SECRETS_IDENTITY to the paper key" >&2
            exit 1
          fi
        fi
        cd ${lib.escapeShellArg "${config.modules.dotfiles.dir}/secrets"}
        agenix ${agenixArgs} -i "$identity"
      '';
    };
in
{
  options.modules.secrets.admin.enable = lib.mkEnableOption ''
    secrets-edit and secrets-rekey, which edit and rekey secrets/ with an
    admin YubiKey. Only for hosts trusted to see every secret'';

  config = {
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    hm.home.packages = lib.mkIf cfg.admin.enable [
      pkgs.age-plugin-yubikey
      (withAdminKey "secrets-edit" "file=\${1:?usage: secrets-edit <file.age>}" ''-e "$file"'')
      (withAdminKey "secrets-rekey" "" "-r")
    ];
  };
}
