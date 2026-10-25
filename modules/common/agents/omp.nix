# modules/common/agents/omp.nix
#
# Oh My Pi, its config, and the Solforge themes from the solforge-theme input.
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
    modules.dotfiles.homeLink = {
      ".omp/agent/config.yml" = "omp/config.yml";
      ".omp/agent/models.yml" = "omp/models.yml";
      ".omp/agent/AGENTS.md" = "omp/AGENTS.md";
      ".omp/agent/TITLE_SYSTEM.md" = "omp/TITLE_SYSTEM.md";
      ".omp/agent/commands/curate-skills.md" = "omp/commands/curate-skills.md";
    };
    hm = {
      home.packages = [ pkgs.omp ];
      home.file =
        lib.genAttrs
          [
            ".omp/agent/themes/solforge-dark.json"
            ".omp/agent/themes/solforge-light.json"
          ]
          (target: {
            source = "${inputs.solforge-theme}/omp/${builtins.baseNameOf target}";
          });
    };
  };
}
