# modules/nixos/services/tailscale.nix
#
# macOS hosts use the Tailscale app cask; see modules/darwin/services/tailscale.nix.
{ config, lib, ... }:

let
  cfg = config.modules.services.tailscale;
in
{
  options.modules.services.tailscale.enable = lib.mkEnableOption "Tailscale";

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      extraSetFlags = [ "--operator=${config.user.name}" ];
    };
  };
}
