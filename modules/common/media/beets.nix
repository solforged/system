{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.media.beets;
  plugins = [
    "albumtypes"
    "chroma"
    "embedart"
    "fetchart"
    "lastgenre"
    "lyrics"
    "musicbrainz"
    "parentwork"
    "replaygain"
    "zero"
  ];
  beets = pkgs.python3Packages.toPythonApplication (
    pkgs.python3Packages.beets.override {
      disableAllPlugins = true;
      pluginOverrides = lib.genAttrs plugins (_: {
        enable = true;
      });
    }
  );
in
{
  options.modules.media.beets.enable = lib.mkEnableOption "Beets music library and fingerprinting";
  config = lib.mkIf cfg.enable {
    hm.home.packages = [
      beets
      pkgs.chromaprint
      pkgs.ffmpeg
    ];
    modules.dotfiles.configLink."beets/config.yaml" = "beets/config.yaml";
  };
}
