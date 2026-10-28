{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.fonts.geist.enable = lib.mkEnableOption "Geist and Geist Mono";
  config = lib.mkIf config.modules.fonts.geist.enable {
    fonts.packages = [ pkgs.geist-font ];
  };
}
