{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.agents.pi;
in
{
  options.modules.agents.pi.enable = lib.mkEnableOption "Pi coding agent";
  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.pi-coding-agent ];
  };
}
