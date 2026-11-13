# packages/ssh-enroll.nix
#
# Creates this host's YubiKey FIDO2 key and signing key, or the backup
# YubiKey's resident key, and registers them on GitHub; see ssh-enroll.sh.
# gh comes from the caller's PATH so its login applies. On a host that does
# not have it yet: nix run ~/src/system#ssh-enroll.
{
  lib,
  stdenv,
  writeShellApplication,
  coreutils,
  gawk,
  gnugrep,
  openssh,
  ssh-tpm-agent,
}:

writeShellApplication {
  name = "ssh-enroll";
  runtimeInputs = [
    coreutils
    gawk
    gnugrep
    openssh
  ]
  # ssh-tpm-keygen, for the signing key on hosts without a Secure Enclave.
  ++ lib.optional stdenv.hostPlatform.isLinux ssh-tpm-agent;
  text = builtins.readFile ./ssh-enroll.sh;
}
