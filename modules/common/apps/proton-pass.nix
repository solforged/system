# modules/common/apps/proton-pass.nix
#
# The Proton Pass app, as a password manager only: SSH keys live on the
# YubiKeys and in each host's Secure Enclave or TPM, and secrets in agenix
# (docs/secrets.md). modules/darwin and modules/nixos install it.
{ lib, ... }:

{
  options.modules.apps.proton-pass.enable = lib.mkEnableOption "the Proton Pass app";
}
