{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.fonts.ibmPlex.enable = lib.mkEnableOption "IBM Plex fonts";
  config = lib.mkIf config.modules.fonts.ibmPlex.enable {
    fonts.packages = [ pkgs.ibm-plex ];
  };
}
