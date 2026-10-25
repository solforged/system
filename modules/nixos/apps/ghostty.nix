# modules/nixos/apps/ghostty.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.modules.apps.ghostty.enable {
    hm.home.packages = [ pkgs.ghostty ];
  };
}
