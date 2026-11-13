# packages/ssh-enroll.nix
#
# Creates this host's YubiKey FIDO2 key and signing key, or the backup
# YubiKey's resident key, and registers them on GitHub; see ssh-enroll.sh.
# gh comes from the caller's PATH so its login applies. On a host that does
# not have it yet: nix run ~/src/system#ssh-enroll.
{
  writeShellApplication,
  coreutils,
  gnugrep,
  openssh,
}:

writeShellApplication {
  name = "ssh-enroll";
  runtimeInputs = [
    coreutils
    gnugrep
    openssh
  ];
  text = builtins.readFile ./ssh-enroll.sh;
}
