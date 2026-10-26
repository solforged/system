# modules/common/editors/helix.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.editors.helix;
in
{
  options.modules.editors.helix.enable = lib.mkEnableOption "Helix";

  config = lib.mkIf cfg.enable {
    # Keep settings live without placing generated themes in the checkout.
    modules.dotfiles.configLink = {
      "helix/config.toml" = "helix/config.toml";
      "helix/languages.toml" = "helix/languages.toml";
    };
    hm = hm: {
      home.packages = with pkgs; [
        helix
        # Language servers named in config/helix/languages.toml
        marksman
        pyright
        ruff
        taplo
      ];
      xdg.configFile =
        lib.genAttrs
          [
            "helix/themes/solforge-dark.toml"
            "helix/themes/solforge-light.toml"
          ]
          (target: {
            source = "${inputs.solforge-theme}/helix/${builtins.baseNameOf target}";
          });
      # Do not let the old whole-directory link redirect theme installation
      # into the checkout. Never remove a real directory or an unrelated link.
      home.activation.migrateHelixDirectory =
        hm.lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            target=${lib.escapeShellArg "${hm.config.xdg.configHome}/helix"}
            source=${lib.escapeShellArg "${config.modules.dotfiles.dir}/config/helix"}
            if [[ -L "$target" && -d "$source" && "$(readlink -f -- "$target")" == "$(readlink -f -- "$source")" ]]; then
              run rm -- "$target"
            fi
          '';
    };
  };
}
