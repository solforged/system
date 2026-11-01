{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.apps.herdr-desktop;
  variants = [
    "dark"
    "light"
  ];
  themeFor = import ./_herdr-theme.nix {
    inherit lib;
    theme = inputs.solforge-theme;
  };
  settings = pkgs.writeText "herdr-settings.json" (
    builtins.toJSON { theme = lib.genAttrs variants (variant: "solforge-${variant}"); }
  );
in
{
  options.modules.apps.herdr-desktop.enable = lib.mkEnableOption "Herdr desktop app";

  config = lib.mkIf cfg.enable {
    hm = hm: {
      # The desktop app uses herdr-core, not the independent herdr TUI daemon.
      home.packages = [
        pkgs.herdr-desktop
        pkgs.herdr-core
      ];
      # Herdr uses ~/.config/herdr-app on macOS too, not Application Support.
      xdg.configFile = lib.listToAttrs (
        map (
          variant:
          lib.nameValuePair "herdr-app/themes/solforge-${variant}.json" {
            text = builtins.toJSON (themeFor variant);
          }
        ) variants
      );
      # Settings are app-writable. Own only the theme pair; leave fonts, zoom,
      # appearance, privacy and all per-layout theme picks alone.
      home.activation.herdrSettings = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe pkgs.python3} ${../../../config/herdr/merge-settings.py} \
          ${settings} ${lib.escapeShellArg "${hm.config.xdg.configHome}/herdr-app/settings.json"}
      '';
    };
  };
}
