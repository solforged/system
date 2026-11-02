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
    }
    # Slash commands from config/omp/commands. /wiki links into the omp-wiki
    # checkout below.
    // lib.listToAttrs (
      map (name: lib.nameValuePair "omp/agent/commands/${name}.md" "omp/commands/${name}.md") [
        "audit"
        "clickaround"
        "commit-groups"
        "curate-skills"
        "fix-findings"
        "land"
        "reconcile"
        "take-stock"
        "tidy"
      ]
    );
    hm =
      hm:
      let
        managedSkills = "${hm.config.xdg.dataHome}/omp/managed-skills";
      in
      {
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
            # omp always writes managed skills to <agent dir>/managed-skills and
            # has no setting to move them, so that path links to XDG data.
            "omp/agent/managed-skills".source = hm.config.lib.file.mkOutOfStoreSymlink managedSkills;
          };
        # Move an existing skills directory to XDG data before Home Manager
        # would back it up as managed-skills.hm-backup. Never merge two
        # non-empty directories.
        home.activation.migrateOmpManagedSkills = hm.lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          link=${lib.escapeShellArg "${hm.config.xdg.configHome}/omp/agent/managed-skills"}
          target=${lib.escapeShellArg managedSkills}
          if [[ -d "$link" && ! -L "$link" ]]; then
            if [[ -d "$target" && -n "$(ls -A -- "$target")" ]]; then
              errorEcho "Both $link and $target hold omp managed skills; merge them by hand."
              exit 1
            fi
            run mkdir -p -- "$(dirname -- "$target")"
            if [[ -d "$target" ]]; then run rmdir -- "$target"; fi
            run mv -- "$link" "$target"
          elif [[ -L "$link" && "$(readlink -- "$link")" != /nix/store/* \
            && "$(readlink -f -- "$link")" == "$(readlink -f -- "$target")" ]]; then
            # A hand-made link to the same place; Home Manager replaces it.
            run rm -- "$link"
          fi
          run mkdir -p -- "$target"
        '';
      };
  };
}
