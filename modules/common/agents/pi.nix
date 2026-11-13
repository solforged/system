# modules/common/agents/pi.nix
#
# Pi from the llm-agents input, in its own home, ~/.pi/agent. Extensions and
# roles come from the live ~/src/pi-mono checkout; pi-setup clones it and the
# memory wiki and links them in. Activation only checks for them: cloning
# needs the network and GitHub keys, so pi-setup stays a manual step.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.agents.pi;
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
  herdr = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
  # Extract the integration bundled with the pinned TUI in a build sandbox,
  # not the user's home during activation. Desktop uses Pi's native OSC 7501.
  herdrPiIntegration = pkgs.runCommand "herdr-pi-integration-${herdr.version}" { } ''
    export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config"
    export PI_CODING_AGENT_DIR="$out"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$PI_CODING_AGENT_DIR"
    ${lib.getExe herdr} integration install pi
    test -s "$out/extensions/herdr-agent-state.ts"
  '';
in
{
  options.modules.agents.pi = {
    enable = lib.mkEnableOption "Pi coding agent";
    herdrTuiIntegration.enable =
      lib.mkEnableOption "Herdr TUI state and session integration for Pi"
      // {
        default = config.modules.agents.herdr.enable;
        defaultText = lib.literalExpression "config.modules.agents.herdr.enable";
      };
  };
  config = lib.mkIf cfg.enable {
    modules.dotfiles.homeLink.".pi/agent/AGENTS.md" = "agents/AGENTS.md";
    hm =
      hm:
      let
        wiki = "${hm.config.xdg.dataHome}/wiki";
        required = [
          "${hm.config.home.homeDirectory}/src/pi-mono/.git"
          "${wiki}/bin/wiki"
        ]
        ++ lib.optional (config.modules.agents.wiki.scope == "home") "${wiki}/home/.git";
      in
      {
        home.file = lib.mkIf cfg.herdrTuiIntegration.enable {
          ".pi/agent/extensions/herdr-agent-state.ts".source =
            "${herdrPiIntegration}/extensions/herdr-agent-state.ts";
        };
        home.packages = [
          pi
          pkgs.pi-setup
        ];
        home.activation.piSetupNotice = hm.lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          missing=""
          for path in ${lib.escapeShellArgs required}; do
            [ -e "$path" ] || missing="$missing $path"
          done
          if [ -n "$missing" ]; then
            noteEcho "Pi setup is incomplete; run pi-setup. Missing:$missing"
          fi
        '';
      };
  };
}
