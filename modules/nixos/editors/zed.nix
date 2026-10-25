# modules/nixos/editors/zed.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.modules.editors.zed.enable {
    hm.home.packages = [ pkgs.zed-editor ];
  };
}
