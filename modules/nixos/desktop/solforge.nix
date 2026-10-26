# GNOME port of the pinned Solforge palettes; upstream owns all colors/artwork.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.desktop.solforge;
  variants = [
    "dark"
    "light"
  ];
  themeDir = variant: "${inputs.solforge-theme}/omarchy-solforge-${variant}-theme";
  paletteFor = variant: builtins.fromTOML (builtins.readFile "${themeDir variant}/colors.toml");
  palette = paletteFor cfg.variant;
  shellCss =
    variant:
    let
      tokens = (paletteFor variant) // {
        inherit variant;
      };
      names = builtins.attrNames tokens;
    in
    builtins.replaceStrings (map (name: "@${name}@") names) (map (name: tokens.${name}) names) (
      builtins.readFile ../../../config/gnome/solforge-shell.css
    );

  # adw-gtk3 and libadwaita share these roles. Keep GTK 4's layout/stylesheet
  # intact: override colors, not the entire toolkit theme or GTK_THEME.
  colors = {
    accent_color = palette.accent;
    accent_bg_color = palette.accent;
    accent_fg_color = palette.background;
    destructive_color = palette.red;
    destructive_bg_color = palette.red;
    destructive_fg_color = palette.background;
    success_color = palette.green;
    success_bg_color = palette.green;
    success_fg_color = palette.background;
    warning_color = palette.yellow;
    warning_bg_color = palette.yellow;
    warning_fg_color = palette.background;
    error_color = palette.red;
    error_bg_color = palette.red;
    error_fg_color = palette.background;
    window_bg_color = palette.background;
    window_fg_color = palette.foreground;
    view_bg_color = palette.dark_background;
    view_fg_color = palette.foreground;
    headerbar_bg_color = palette.lighter_background;
    headerbar_fg_color = palette.foreground;
    headerbar_border_color = palette.muted;
    headerbar_backdrop_color = palette.background;
    sidebar_bg_color = palette.lighter_background;
    sidebar_fg_color = palette.foreground;
    sidebar_backdrop_color = palette.background;
    secondary_sidebar_bg_color = palette.background;
    secondary_sidebar_fg_color = palette.foreground;
    secondary_sidebar_backdrop_color = palette.dark_background;
    card_bg_color = palette.lighter_background;
    card_fg_color = palette.foreground;
    dialog_bg_color = palette.background;
    dialog_fg_color = palette.foreground;
    popover_bg_color = palette.lighter_background;
    popover_fg_color = palette.foreground;
    thumbnail_bg_color = palette.lighter_background;
    thumbnail_fg_color = palette.foreground;
    panel_bg_color = palette.darker_background;
    panel_fg_color = palette.foreground;
  };
  namedColors = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "@define-color ${name} ${value};") colors
  );
  # Modern libadwaita uses CSS variables. Set these too, including standalone
  # accent colors, so it doesn't derive a different gilt via its Oklab transform.
  cssVariables = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "  --${lib.replaceStrings [ "_" ] [ "-" ] name}: ${value};") colors
  );
in
{
  options.modules.desktop.solforge = {
    enable = lib.mkEnableOption "Solforge GTK, libadwaita and GNOME Shell themes";
    variant = lib.mkOption {
      type = lib.types.enum variants;
      default = "dark";
      description = "Desktop palette. Rebuild and restart apps after changing it.";
    };
    wallpaper = lib.mkOption {
      type = lib.types.enum [
        "00-fucina.png"
        "01-specchio.png"
        "02-orologio.png"
        "03-vacui.png"
        "04-oculus.png"
      ];
      default = "00-fucina.png";
      description = "Solforge notebook drawing used for the desktop background.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.desktop.gnome.enable;
        message = "modules.desktop.solforge requires modules.desktop.gnome.enable.";
      }
    ];

    environment.systemPackages = [ pkgs.gnomeExtensions.user-themes ];

    hm = {
      gtk = {
        enable = true;
        # adw-gtk3 has no GTK 2 theme; leave those apps on their native defaults.
        gtk2.enable = false;
        colorScheme = cfg.variant;
        theme = {
          package = pkgs.adw-gtk3;
          name = if cfg.variant == "dark" then "adw-gtk3-dark" else "adw-gtk3";
        };
        gtk3.extraCss = namedColors;
        gtk4.extraCss = namedColors + "\n:root {\n${cssVariables}\n}\n";
      };

      xdg.dataFile = lib.listToAttrs (
        map (variant: {
          name = "themes/Solforge-${variant}/gnome-shell/gnome-shell.css";
          value.text = shellCss variant;
        }) variants
      );

      dconf.settings = {
        "org/gnome/desktop/interface".accent-color = "yellow";
        "org/gnome/desktop/background" = {
          picture-uri = "file://${themeDir "light"}/backgrounds/${cfg.wallpaper}";
          picture-uri-dark = "file://${themeDir "dark"}/backgrounds/${cfg.wallpaper}";
          picture-options = "zoom";
        };
        "org/gnome/shell".enabled-extensions = [ pkgs.gnomeExtensions.user-themes.extensionUuid ];
        "org/gnome/shell/extensions/user-theme".name = "Solforge-${cfg.variant}";
        "org/gnome/shell/extensions/dash-to-panel" = {
          trans-use-custom-bg = true;
          trans-bg-color = palette.darker_background;
          trans-use-custom-opacity = true;
          trans-panel-opacity = 1.0;
          dot-color-override = true;
          dot-color-1 = palette.accent;
          dot-color-2 = palette.accent;
          dot-color-3 = palette.accent;
          dot-color-4 = palette.accent;
          focus-highlight-color = palette.accent;
          highlight-appicon-hover-background-color = palette.lighter_background;
          highlight-appicon-pressed-background-color = palette.selection;
        };
        "org/gnome/shell/extensions/arcmenu" = {
          override-menu-theme = true;
          menu-background-color = palette.background;
          menu-foreground-color = palette.foreground;
          menu-border-color = palette.muted;
          menu-separator-color = palette.muted;
          menu-item-hover-bg-color = palette.selection;
          menu-item-hover-fg-color = palette.selection_foreground;
          menu-item-active-bg-color = palette.accent;
          menu-item-active-fg-color = palette.background;
        };
      };
    };
  };
}
