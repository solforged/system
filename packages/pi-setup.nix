# packages/pi-setup.nix
#
# Clones pi-mono and the memory wiki, builds the wiki tool, and links
# pi-mono's extensions into ~/.pi/agent. go and node come from the caller's
# PATH, the versions modules.dev provides.
{
  writeShellApplication,
  coreutils,
  git,
}:

writeShellApplication {
  name = "pi-setup";
  runtimeInputs = [
    coreutils
    git
  ];
  text = builtins.readFile ./pi-setup.sh;
}
