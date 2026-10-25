{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.media.import;
  media-import = pkgs.writeShellApplication {
    name = "media-import";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      rsync
      curl
      python3
    ];
    text = builtins.readFile ../../../bin/media-import;
  };
in
{
  options.modules.media.import.enable =
    lib.mkEnableOption "Copy completed VM downloads to the media library";
  config = lib.mkIf cfg.enable {
    hm.home.packages = [ media-import ];
  };
}
