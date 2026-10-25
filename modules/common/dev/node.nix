{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.dev.node;
in
{
  options.modules.dev.node.enable = lib.mkEnableOption "Node.js and Bun development";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [
      pkgs.nodejs_26
      pkgs.bun
    ];
  };
}
