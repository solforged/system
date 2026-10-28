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
  pi = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;
in
{
  options.modules.agents.pi.enable = lib.mkEnableOption "Pi coding agent";
  config = lib.mkIf cfg.enable {
    # ~/.config/pi/agent rather than ~/.pi/agent. Set in a wrapper because
    # omp reads PI_CODING_AGENT_DIR too.
    hm.home.packages = [
      (pkgs.symlinkJoin {
        inherit (pi) name meta;
        paths = [ pi ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/pi \
            --run 'export PI_CODING_AGENT_DIR="''${PI_CODING_AGENT_DIR:-''${XDG_CONFIG_HOME:-$HOME/.config}/pi/agent}"'
        '';
      })
    ];
  };
}
