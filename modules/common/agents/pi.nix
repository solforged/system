# modules/common/agents/pi.nix
#
# Pi from the llm-agents input, in its own home, ~/.pi/agent. Extensions and
# roles come from the live ~/src/pi-mono checkout; pi-setup clones it and the
# memory wiki and links them in.
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
    hm.home.file = lib.mkIf cfg.herdrTuiIntegration.enable {
      ".pi/agent/extensions/herdr-agent-state.ts".source =
        "${herdrPiIntegration}/extensions/herdr-agent-state.ts";
    };
    hm.home.packages = [
      pi
      pkgs.pi-setup
    ];
  };
}
