# modules/common/agents/claude.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.agents.claude;
in
{
  options.modules.agents.claude.enable = lib.mkEnableOption "Claude Code";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.claude-code ];
  };
}
