# packages/vale-voice.nix
#
# Vendors the Voice prose style from the live checkout into a repository's
# Vale StylesPath, and starts a .vale.ini for a repository without one.
{
  writeShellApplication,
  coreutils,
  gawk,
  git,
  rsync,
}:

writeShellApplication {
  name = "vale-voice";
  runtimeInputs = [
    coreutils
    gawk
    git
    rsync
  ];
  text = builtins.readFile ./vale-voice.sh;
}
