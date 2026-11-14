# modules/darwin/services/tailscale.nix
#
# The Tailscale app from its signed cask, which runs the network extension
# and lets Rex and Remote Login reach this Mac. Sign in from the menu bar app
# after the first switch.
{ config, lib, ... }:

let
  cfg = config.modules.services.tailscale;
in
{
  options.modules.services.tailscale.enable = lib.mkEnableOption "Tailscale";

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "tailscale" ];
  };
}
