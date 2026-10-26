# modules/nixos/desktop/gnome.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop.gnome;
  shellExtensions = with pkgs.gnomeExtensions; [
    dash-to-panel
    arcmenu
    tiling-assistant
    appindicator
  ];
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

    environment.systemPackages =
      shellExtensions
      ++ (with pkgs; [
        gnome-tweaks
        # Native Wayland clipboard access for terminal apps and editors.
        wl-clipboard
      ]);
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
        "org/gnome/desktop/wm/preferences" = {
          button-layout = ":minimize,maximize,close";
        };
        "org/gnome/desktop/wm/keybindings" = {
          # Alt-Tab selects windows rather than grouping them by application.
          switch-applications = mkEmptyArray type.string;
          switch-applications-backward = mkEmptyArray type.string;
          switch-windows = [ "<Alt>Tab" ];
          switch-windows-backward = [ "<Shift><Alt>Tab" ];
          show-desktop = [ "<Super>d" ];
        };
        "org/gnome/mutter" = {
          experimental-features = [ "scale-monitor-framebuffer" ];
          dynamic-workspaces = true;
        };
        "org/gnome/shell" = {
          disable-user-extensions = false;
          # Keep this mergeable: the personal-apps module also enables GSConnect.
          enabled-extensions = map (extension: extension.extensionUuid) shellExtensions;
        };
        "org/gnome/shell/keybindings" = {
          # ArcMenu takes the bare Super key; retain easy access to the overview.
          toggle-overview = [ "<Super>Tab" ];
        };
        "org/gnome/shell/extensions/dash-to-panel" = {
          # These settings are JSON strings keyed by monitor, not GVariant maps.
          panel-positions = builtins.toJSON { "0" = "BOTTOM"; };
          panel-sizes = builtins.toJSON { "0" = 48; };
          panel-element-positions = builtins.toJSON {
            "0" = [
              {
                element = "showAppsButton";
                visible = false;
                position = "stackedTL";
              }
              {
                element = "activitiesButton";
                visible = false;
                position = "stackedTL";
              }
              {
                element = "leftBox";
                visible = true;
                position = "stackedTL";
              }
              {
                element = "taskbar";
                visible = true;
                position = "stackedTL";
              }
              {
                element = "centerBox";
                visible = true;
                position = "stackedBR";
              }
              {
                element = "rightBox";
                visible = true;
                position = "stackedBR";
              }
              {
                element = "systemMenu";
                visible = true;
                position = "stackedBR";
              }
              {
                element = "dateMenu";
                visible = true;
                position = "stackedBR";
              }
              {
                element = "desktopButton";
                visible = true;
                position = "stackedBR";
              }
            ];
          };
          stockgs-keep-top-panel = false;
          stockgs-keep-dash = false;
          intellihide = false;
          group-apps = true;
          click-action = "TOGGLE-SHOWPREVIEW";
          shift-click-action = "LAUNCH";
          middle-click-action = "LAUNCH";
          hot-keys = true;
          hide-overview-on-startup = true;
        };
        "org/gnome/shell/extensions/arcmenu" = {
          menu-layout = "redmond";
          position-in-panel = "Left";
          arcmenu-hotkey = [ "Super_L" ];
          arcmenu-hotkey-overlay-key-enabled = true;
          activate-on-launch = true;
          # Extensions are updated with nixpkgs, not through the GNOME website.
          update-notifier-enabled = false;
        };
        "org/gnome/shell/extensions/tiling-assistant" = {
          enable-tiling-popup = true;
          enable-raise-tile-group = true;
          # Super+arrows can progress from halves to quarters, as on Windows.
          dynamic-keybinding-behavior = 3;
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/files/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/files" = {
          name = "Files";
          command = "${lib.getExe pkgs.nautilus} --new-window";
          binding = "<Super>e";
        };
      };
    };
  };
}
