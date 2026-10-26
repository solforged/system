# modules/common/apps/ghostty.nix
#
# The app comes from modules/nixos/apps/ghostty.nix or the darwin cask.
{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.modules.apps.ghostty;
in
{
  options.modules.apps.ghostty.enable = lib.mkEnableOption "Ghostty";

  config = lib.mkIf cfg.enable {
    # Link just the config: Home Manager owns the sibling theme files.
    modules.dotfiles.configLink."ghostty/config.ghostty" = "ghostty/config.ghostty";
    hm = hm: {
      xdg.configFile =
        lib.genAttrs
          [
            "ghostty/themes/solforge-dark"
            "ghostty/themes/solforge-light"
          ]
          (target: {
            source = "${inputs.solforge-theme}/ghostty/${builtins.baseNameOf target}";
          });
      # Legacy HM keeps an old directory link if the new generation has a
      # directory at that path. Remove only our old link before adding children.
      home.activation.migrateGhosttyDirectory =
        hm.lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            target=${lib.escapeShellArg "${hm.config.xdg.configHome}/ghostty"}
            source=${lib.escapeShellArg "${config.modules.dotfiles.dir}/config/ghostty"}
            if [[ -L "$target" && -d "$source" && "$(readlink -f -- "$target")" == "$(readlink -f -- "$source")" ]]; then
              run rm -- "$target"
            fi
          '';
    };
  };
}
