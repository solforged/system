# modules/nixos/security/ssh-signing.nix
#
# Commit signing keys sealed to the TPM. ssh-enroll makes this host's
# ~/.ssh/id_ecdsa_signing.tpm, which works only with this machine's TPM, and
# ssh-tpm-agent serves every *.tpm key in ~/.ssh without a prompt. Git and jj
# reach the agent through modules/common/shell/vcs/_common.nix. ssh-enroll
# needs the tss group, so log in again after the first switch.
{ config, lib, ... }:

let
  cfg = config.modules.shell.vcs;
in
{
  config = lib.mkIf (cfg.enable && cfg.sign) {
    security.tpm2.enable = true;
    users.users.${config.user.name}.extraGroups = [ config.security.tpm2.tssGroup ];
    # Nothing else should claim SSH_AUTH_SOCK: GNOME's agent would.
    services.gnome.gcr-ssh-agent.enable = false;
    hm.services.ssh-tpm-agent.enable = true;
    # The module would export SSH_AUTH_SOCK from each shell's Home Manager
    # config, which the live-linked shell configs here replace. Only signing
    # needs the agent, and the signing wrapper finds its socket itself.
    hm.sshAuthSock.enable = lib.mkForce false;
  };
}
