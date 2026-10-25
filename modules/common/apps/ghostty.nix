# modules/common/apps/ghostty.nix
#
# The app comes from modules/nixos/apps/ghostty.nix or the darwin cask.
{ config, lib, ... }:

let
  cfg = config.modules.apps.ghostty;
in
{
  options.modules.apps.ghostty.enable = lib.mkEnableOption "Ghostty";

  config = lib.mkIf cfg.enable {
    modules.dotfiles.configLink.ghostty = "ghostty";
  };
}
