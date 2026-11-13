# packages/ssh-enroll.nix
#
# Creates this host's ~/.ssh/id_ed25519 if missing and registers it on
# GitHub for push and signing. gh comes from the caller's PATH so its login
# applies.
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
