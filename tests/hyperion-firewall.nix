# Check the evaluated policy and generated shell without running OS commands.
{ pkgs, configuration }:
let
  inherit (pkgs) lib;
  firewall = configuration.config.networking.applicationFirewall;
  activation = configuration.config.system.activationScripts.networking.text;
  commands = [
    "--setglobalstate on"
    "--setblockall off"
    "--setallowsigned on"
    "--setallowsignedapp on"
    "--setstealthmode off"
  ];
in
assert
  firewall == {
    enable = true;
    blockAllIncoming = false;
    allowSigned = true;
    allowSignedApp = true;
    enableStealthMode = false;
  };
assert lib.all (
  command: lib.hasInfix "/usr/libexec/ApplicationFirewall/socketfilterfw ${command}" activation
) commands;
pkgs.runCommand "hyperion-firewall-check"
  {
    nativeBuildInputs = [ pkgs.bash ];
  }
  ''
    bash -n ${pkgs.writeText "hyperion-networking-activation.sh" activation}
    touch "$out"
  ''
