# Herdr's terminal workspace manager from the pinned llm-agents input.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.agents.herdr;
in
{
  options.modules.agents.herdr.enable = lib.mkEnableOption "Herdr terminal workspace manager";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr ];
  };
}
