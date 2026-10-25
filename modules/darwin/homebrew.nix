# modules/darwin/homebrew.nix
#
# Hosts and app modules add to homebrew.brews and homebrew.casks.
{ config, lib, ... }:

let
  prefix = config.homebrew.prefix;
in
{
  # After the Nix profiles, so a formula never shadows a Nix package.
  environment.systemPath = lib.mkAfter [
    "${prefix}/bin"
    "${prefix}/sbin"
  ];
  modules.env.variables.HOMEBREW_NO_ENV_HINTS = "1";

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      # "zap" would uninstall every formula and cask not listed here. Switch
      # to it once each host's lists cover what is installed.
      cleanup = "none";
    };
    casks =
      lib.optional config.modules.apps.ghostty.enable "ghostty"
      ++ lib.optional config.modules.editors.zed.enable "zed";
  };
}
