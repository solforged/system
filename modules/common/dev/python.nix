{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.dev.python;
in
{
  options.modules.dev.python.enable = lib.mkEnableOption "Python development";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.python315 ];
  };
}
