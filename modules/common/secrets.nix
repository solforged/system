# modules/common/secrets.nix
#
# agenix decrypts secrets/*.age at activation with this host's SSH host key.
# The key must exist and be listed in secrets/agenix-rules.nix before the first
# switch; on macOS, `sudo ssh-keygen -A` creates it without turning on Remote
# Login.
#
# Editing and rekeying need the admin age key, kept in Proton Pass as the
# password of the "agenix admin" item. `secrets-edit <file>` and
# `secrets-rekey` fetch it through fnox into a private temp file for the
# length of one agenix run.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  agenix = inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  fnoxConfig = (pkgs.formats.toml { }).generate "agenix-fnox.toml" {
    providers.protonpass = {
      type = "proton-pass";
      vault = "Personal";
    };
    secrets.AGENIX_ADMIN_KEY = {
      provider = "protonpass";
      value = "agenix admin";
      description = "Age identity that can decrypt every file in secrets/";
    };
  };

  withAdminKey =
    name: setup: agenixArgs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        agenix
        pkgs.coreutils
        pkgs.fnox
        pkgs.proton-pass-cli
      ];
      text = ''
        ${setup}
        key=$(mktemp)
        trap 'rm -f "$key"' EXIT
        fnox --no-daemon -c ${fnoxConfig} get AGENIX_ADMIN_KEY >"$key"
        cd ${lib.escapeShellArg "${config.modules.dotfiles.dir}/secrets"}
        agenix ${agenixArgs} -i "$key"
      '';
    };
in
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  hm.home.packages = lib.mkIf config.modules.apps.proton-pass.enable [
    (withAdminKey "secrets-edit" "file=\${1:?usage: secrets-edit <file.age>}" ''-e "$file"'')
    (withAdminKey "secrets-rekey" "" "-r")
  ];
}
