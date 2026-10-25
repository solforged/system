# modules/nixos/desktop/gnome.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.gnome;
in
{
  options.modules.desktop.gnome.enable = lib.mkEnableOption "GNOME on Wayland";

  config = lib.mkIf cfg.enable {
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    environment.gnome.excludePackages = with pkgs; [
      epiphany
      geary
      gnome-music
      gnome-tour
    ];

    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnomeExtensions.appindicator
    ];
    services.udev.packages = [ pkgs.gnome-settings-daemon ];

    hm = hm: {
      dconf.settings = with hm.lib.hm.gvariant; {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          enable-hot-corners = false;
        };
        "org/gnome/desktop/peripherals/keyboard" = {
          repeat-interval = mkUint32 15;
          delay = mkUint32 200;
        };
        "org/gnome/mutter" = {
          experimental-features = [ "scale-monitor-framebuffer" ];
          dynamic-workspaces = true;
        };
        "org/gnome/shell" = {
          enabled-extensions = [ "appindicatorsupport@rgcjonas.gmail.com" ];
        };
      };
    };
  };
}
