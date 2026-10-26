{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.games.desktop;
in
{
  options.modules.games.desktop.enable = lib.mkEnableOption "Desktop games and Wine";
  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
      # Steam's web UI runs in the Steam Runtime container, which only sees the
      # FHS env's /usr/share/icons. Without a cursor theme there, libXcursor
      # falls back to the tiny X core cursor font.
      extraPackages = [ pkgs.adwaita-icon-theme ];
    };
    hardware.graphics.enable32Bit = true;
    hm.home.packages = with pkgs; [
      gamescope
      lutris
      umu-launcher
      winetricks
      (wineWow64Packages.staging.override { embedInstallers = true; })
    ];
  };
}
