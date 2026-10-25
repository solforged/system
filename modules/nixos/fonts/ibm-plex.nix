{ config, lib, ... }:
{
  config = lib.mkIf config.modules.fonts.ibmPlex.enable {
    fonts.fontconfig.defaultFonts = {
      sansSerif = [ "IBM Plex Sans" ];
      serif = [ "IBM Plex Serif" ];
    };
  };
}
