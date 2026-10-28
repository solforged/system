# modules/common/agents/omp.nix
#
# Oh My Pi from the llm-agents input, its config, and the Solforge themes from
# the solforge-theme input. Its root is ~/.config/omp rather than ~/.omp.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.agents.omp;
in
{
  options.modules.agents.omp.enable = lib.mkEnableOption "Oh My Pi";
  config = lib.mkIf cfg.enable {
    # Taken relative to $HOME. Not PI_CODING_AGENT_DIR: pi reads that too.
    modules.env.variables.PI_CONFIG_DIR = ".config/omp";
    modules.dotfiles.configLink = {
      "omp/agent/config.yml" = "omp/config.yml";
      "omp/agent/models.yml" = "omp/models.yml";
      "omp/agent/AGENTS.md" = "omp/AGENTS.md";
      "omp/agent/TITLE_SYSTEM.md" = "omp/TITLE_SYSTEM.md";
      "omp/agent/commands/curate-skills.md" = "omp/commands/curate-skills.md";
    };
    hm = {
      home.packages = [ inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp ];
      xdg.configFile =
        lib.genAttrs
          [
            "omp/agent/themes/solforge-dark.json"
            "omp/agent/themes/solforge-light.json"
          ]
          (target: {
            source = "${inputs.solforge-theme}/omp/${builtins.baseNameOf target}";
          });
    };
  };
}
