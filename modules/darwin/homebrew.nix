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
      # Hosts override this once their lists cover what is installed.
      # "zap" also deletes the files a removed cask owns.
      cleanup = lib.mkDefault "none";
    };
    casks =
      lib.optional config.modules.apps.claude-desktop.enable "claude"
      ++ lib.optional config.modules.apps.ghostty.enable "ghostty"
      ++ lib.optional config.modules.editors.zed.enable "zed";
  };
}
