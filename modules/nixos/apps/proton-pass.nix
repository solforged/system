# modules/nixos/apps/proton-pass.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.modules.apps.proton-pass.enable {
    hm.home.packages = [ pkgs.proton-pass ];
    # The app keeps its session in the desktop's Secret Service.
    services.gnome.gnome-keyring.enable = true;
  };
}
