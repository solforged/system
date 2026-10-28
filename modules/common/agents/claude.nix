# modules/common/agents/claude.nix
#
# Claude Code from the llm-agents input.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.agents.claude;
in
{
  options.modules.agents.claude.enable = lib.mkEnableOption "Claude Code";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code ];
  };
}
