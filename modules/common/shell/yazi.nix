# modules/common/shell/yazi.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.yazi;
in
{
  options.modules.shell.yazi.enable = lib.mkEnableOption "Yazi file manager";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.yazi ];
    modules.dotfiles.configLink.yazi = "yazi";
  };
}
