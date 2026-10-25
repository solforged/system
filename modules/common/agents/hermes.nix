# modules/common/agents/hermes.nix
#
# Hermes Agent from the upstream flake: the CLI and the desktop app, sharing
# ~/.hermes. Hermes still owns config.yaml, .env and auth.json; nothing here
# runs the gateway or serve as a service. The Tunon skin comes from the
# solforge-theme input.
{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.modules.agents.hermes;
in
{
  options.modules.agents.hermes.enable = lib.mkEnableOption "Hermes Agent";

  config = lib.mkIf cfg.enable {
    hm = {
      imports = [ inputs.hermes-agent.homeManagerModules.default ];

      programs.hermes-agent = {
        enable = true;
        desktop.enable = true;
      };

      home.file.".hermes/skins/tunon.yaml".source = "${inputs.solforge-theme}/hermes/tunon.yaml";
    };
  };
}
