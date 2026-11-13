# Check declarative ownership and exercise the pinned TUI hook without Pi,
# credentials, model calls, or a real Herdr server.
{ configuration }:
let
  inherit (configuration) pkgs;
  inherit (pkgs) lib;
  user = configuration.config.user.name;
  target = ".pi/agent/extensions/herdr-agent-state.ts";
  home = configuration.config.home-manager.users.${user};
  homeWith =
    module: (configuration.extendModules { modules = [ module ]; }).config.home-manager.users.${user};
  withoutPi = homeWith { modules.agents.pi.enable = lib.mkForce false; };
  withoutTui = homeWith { modules.agents.herdr.enable = lib.mkForce false; };
  withoutIntegration = homeWith { modules.agents.pi.herdrTuiIntegration.enable = lib.mkForce false; };
in
assert builtins.hasAttr target home.home.file;
assert !(builtins.hasAttr target withoutPi.home.file);
assert !(builtins.hasAttr target withoutTui.home.file);
assert !(builtins.hasAttr target withoutIntegration.home.file);
pkgs.runCommand "herdr-pi-integration-check" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
  export HOME="$TMPDIR/home" TMPDIR="$TMPDIR"
  mkdir -p "$HOME"
  node ${./herdr-pi.mjs} ${home.home.file.${target}.source}
  touch "$out"
''
