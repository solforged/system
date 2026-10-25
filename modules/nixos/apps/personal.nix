{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.apps.personal;
in
{
  options.modules.apps.personal.enable = lib.mkEnableOption "Personal desktop applications";
  config = lib.mkIf cfg.enable {
    hm.home.packages = with pkgs; [
      brave
      calibre
      kdePackages.kdenlive
      obs-studio
      qbittorrent
      signal-desktop
      telegram-desktop
      xournalpp
      filebot
      obsidian
    ];
    programs.kdeconnect = {
      enable = true;
      package = pkgs.gnomeExtensions.gsconnect;
    };
    hm.dconf.settings."org/gnome/shell".enabled-extensions = [ "gsconnect@andyholmes.github.io" ];
  };
}
