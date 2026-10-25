{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.preferences;
in
{
  options.modules.desktop.preferences.enable =
    lib.mkEnableOption "Desktop file associations and user directories";
  config = lib.mkIf cfg.enable {
    hm = hm: {
      home.packages = [
        pkgs.mpv
        pkgs.loupe
        pkgs.papers
      ];
      xdg.mimeApps = {
        enable = true;
        defaultApplications =
          (builtins.fromTOML (builtins.readFile ../../../config/mimeapps/defaults.toml)).defaults;
      };
      xdg.userDirs = {
        enable = true;
        createDirectories = true;
        desktop = hm.config.home.homeDirectory;
        publicShare = hm.config.home.homeDirectory;
        templates = hm.config.home.homeDirectory;
        download = "${hm.config.home.homeDirectory}/Downloads";
        documents = "${hm.config.home.homeDirectory}/Documents";
        music = "${hm.config.home.homeDirectory}/Music";
        pictures = "${hm.config.home.homeDirectory}/Pictures";
        videos = "${hm.config.home.homeDirectory}/Videos";
        extraConfig.XDG_PROJECTS_DIR = "${hm.config.home.homeDirectory}/Projects";
      };
    };
  };
}
