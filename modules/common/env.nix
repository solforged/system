# modules/common/env.nix
#
# One login environment for shells and GUI apps. modules/nixos/env.nix hands
# the variables to PAM; modules/darwin/env.nix hands them to launchd.
{
  config,
  lib,
  my,
  ...
}:

let
  inherit (lib) types;
  cfg = config.modules.env;
in
{
  options.modules.env = {
    variables =
      my.mkOpt' (types.attrsOf types.str) { }
        "Environment variables. Values may use $HOME, but no other variables.";
    path =
      my.mkOpt' (types.listOf types.str) [ ]
        "Directories prepended to PATH in shells. Entries may use $HOME.";
  };

  config.environment.extraInit = lib.mkIf (cfg.path != [ ]) ''
    export PATH="${lib.concatStringsSep ":" cfg.path}:$PATH"
  '';
}
