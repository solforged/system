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
