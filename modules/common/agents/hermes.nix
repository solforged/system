# modules/common/agents/hermes.nix
#
# Hermes Agent from upstream main: the CLI and the desktop app, sharing
# ~/.hermes. The desktop app runs this CLI as its backend. Hermes still owns
# config.yaml, .env and auth.json; nothing here runs the gateway as a service.
# The Tunon skin comes from the solforge-theme input.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.agents.hermes;
  hermes = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system};
  desktop =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.callPackage ../../../packages/hermes-desktop.nix { hermes = inputs.hermes-agent; }
    else
      hermes.desktop;
in
{
  options.modules.agents.hermes.enable = lib.mkEnableOption "Hermes Agent";

  config = lib.mkIf cfg.enable {
    hm = {
      # On Darwin, Home Manager copies Hermes.app to ~/Applications/Home Manager Apps.
      home.packages = [
        hermes.default
        desktop
      ];

      home.file.".hermes/skins/tunon.yaml".source = "${inputs.solforge-theme}/hermes/tunon.yaml";
    };
  };
}
