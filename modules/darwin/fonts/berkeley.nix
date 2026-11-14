{ config, lib, ... }:
let
  user = config.user.name;
  fontsDir = "${config.users.users.${user}.home}/Library/Fonts";
in
{
  config = lib.mkIf config.modules.fonts.berkeley.enable {
    # agenix creates missing parent directories as root. Prepare this one
    # before its launchd job starts, and repair ownership on existing installs
    # so Home Manager can link its font marker and install other fonts.
    system.activationScripts.preActivation.text = ''
      install -d -m 0755 -o ${lib.escapeShellArg user} -g staff ${lib.escapeShellArg fontsDir}
    '';
  };
}
