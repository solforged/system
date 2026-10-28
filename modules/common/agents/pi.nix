# modules/common/agents/pi.nix
#
# Pi from the llm-agents input.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.agents.pi;
in
{
  options.modules.agents.pi.enable = lib.mkEnableOption "Pi coding agent";
  config = lib.mkIf cfg.enable {
    hm.home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi ];
  };
}
