{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.dev.go;
in
{
  options.modules.dev.go.enable = lib.mkEnableOption "Go development";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.go_1_27 ];
  };
}
