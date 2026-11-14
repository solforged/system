# modules/common/agents/omp.nix
#
# Oh My Pi from llm-agents, in its own home, ~/.omp/agent. Settings, prompts
# and commands link live from config/omp; omp-intercom and the Solforge themes
# come from pinned inputs.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.agents.omp;
  omp = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
  commands = [
    "audit"
    "clickaround"
    "commit-groups"
    "curate-skills"
    "fix-findings"
    "land"
    "reconcile"
    "review-commits"
    "take-stock"
    "tidy"
  ];
in
{
  options.modules.agents.omp.enable = lib.mkEnableOption "Oh My Pi";

  config = lib.mkIf cfg.enable {
    modules.dotfiles.homeLink = {
      ".omp/agent/config.yml" = "omp/config.yml";
      ".omp/agent/models.yml" = "omp/models.yml";
      ".omp/agent/AGENTS.md" = "agents/AGENTS.md";
      ".omp/agent/TITLE_SYSTEM.md" = "omp/TITLE_SYSTEM.md";
    }
    // lib.listToAttrs (
      map (name: lib.nameValuePair ".omp/agent/commands/${name}.md" "omp/commands/${name}.md") commands
    );

    hm = {
      home.packages = [ omp ];
      home.file =
        lib.genAttrs
          [
            ".omp/agent/themes/solforge-dark.json"
            ".omp/agent/themes/solforge-light.json"
          ]
          (target: {
            source = "${inputs.solforge-theme}/omp/${builtins.baseNameOf target}";
          })
        // {
          ".omp/agent/extensions/intercom.ts".source = "${inputs.omp-intercom}/intercom.ts";
        };
    };
  };
}
