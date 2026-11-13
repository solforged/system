# Rex's Mac app updates itself and is installed separately; see docs/terminals.md.
{ config, lib, ... }:
{
  options.modules.apps.rex.enable = lib.mkEnableOption "Rex configuration";
  config = lib.mkIf config.modules.apps.rex.enable {
    modules.dotfiles.configLink."rex/init.lua" = "rex/init.lua";
    modules.env.variables.TERMINAL_BROWSER_NO_TELEMETRY = "1";
  };
}
