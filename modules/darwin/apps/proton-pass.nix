# modules/darwin/apps/proton-pass.nix
{ config, lib, ... }:

{
  config = lib.mkIf config.modules.apps.proton-pass.enable {
    homebrew.casks = [ "proton-pass" ];
  };
}
