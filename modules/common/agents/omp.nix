# modules/common/agents/omp.nix
#
# Oh My Pi from llm-agents, omp-intercom, and the Solforge themes from pinned
# inputs, plus the live omp-wiki checkout. Its root is ~/.config/omp rather
# than ~/.omp.
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
  # Runs the live omp-wiki checkout's script, so edits apply without a
  # rebuild, like the linked /wiki command beside it.
  wikiInbox = pkgs.writeShellApplication {
    name = "wiki-inbox";
    runtimeInputs = [
      omp
      pkgs.git
      pkgs.python3
    ];
    text = ''
      exec python3 ${cfg.wiki.dir}/wiki-inbox.py "$@"
    '';
  };
in
{
  options.modules.agents.omp = {
    enable = lib.mkEnableOption "Oh My Pi";
    wiki.dir = lib.mkOption {
      type = lib.types.str;
      default = "${dirOf config.modules.dotfiles.dir}/omp-wiki";
      description = "Live omp-wiki checkout; /wiki, wiki-inbox and the Tern wiki plugin link into it.";
    };
  };
  config = lib.mkIf cfg.enable {
    # Taken relative to $HOME. Not PI_CODING_AGENT_DIR: pi reads that too.
    modules.env.variables.PI_CONFIG_DIR = ".config/omp";
    modules.dotfiles.configLink = {
      "omp/agent/config.yml" = "omp/config.yml";
      "omp/agent/models.yml" = "omp/models.yml";
      "omp/agent/AGENTS.md" = "agents/AGENTS.md";
      "omp/agent/TITLE_SYSTEM.md" = "omp/TITLE_SYSTEM.md";
      "omp/agent/commands/curate-skills.md" = "omp/commands/curate-skills.md";
    };
    hm = hm: {
      home.packages = [
        omp
        wikiInbox
      ];
      xdg.configFile =
        lib.genAttrs
          [
            "omp/agent/themes/solforge-dark.json"
            "omp/agent/themes/solforge-light.json"
          ]
          (target: {
            source = "${inputs.solforge-theme}/omp/${builtins.baseNameOf target}";
          })
        // {
          "omp/agent/extensions/intercom.ts".source = "${inputs.omp-intercom}/intercom.ts";
          "omp/agent/commands/wiki.md".source =
            hm.config.lib.file.mkOutOfStoreSymlink "${cfg.wiki.dir}/wiki.md";
        };
    };
  };
}
