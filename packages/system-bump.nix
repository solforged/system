# packages/system-bump.nix
#
# Updates flake inputs, checks the new lock, and commits it. Used by hand
# (`system-bump`, `system-bump llm-agents --switch`) and by the weekly
# workflow in .github/workflows/bump.yml. nix, gh and jj are not inputs:
# they come from the caller's PATH, so the host's own Nix and logins apply.
{
  writeShellApplication,
  coreutils,
  diffutils,
  git,
  jq,
  nh,
}:

writeShellApplication {
  name = "system-bump";
  runtimeInputs = [
    coreutils
    diffutils
    git
    jq
    nh
  ];
  text = builtins.readFile ./system-bump.sh;
}
