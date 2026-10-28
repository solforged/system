{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.dev.personal.enable = lib.mkEnableOption "personal development tools";
  config = lib.mkIf config.modules.dev.personal.enable {
    modules.dev.android.enable = true;
    hm.home.packages = [
      pkgs.yt-dlp
      pkgs.vale
    ];
    modules.dotfiles = {
      configLink = {
        "vale/.vale.ini" = "vale/vale.ini";
      };
      homeLink.".local/share/vale/styles/Voice" = "vale/styles/Voice";
    };
  };
}
