{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.modules.editors.mitos;
in
{
  options.modules.editors.mitos.enable = lib.mkEnableOption "Mitos";
  config = lib.mkIf cfg.enable {
    modules.dotfiles.configLink = {
      "mitos/config.toml" = "mitos/config.toml";
      "mitos/languages.toml" = "mitos/languages.toml";
    };
    hm = {
      home.packages = with pkgs; [
        mitos
        marksman
        pyright
        ruff
        taplo
      ];
      xdg.configFile =
        lib.genAttrs
          [
            "mitos/themes/solforge-dark.toml"
            "mitos/themes/solforge-light.toml"
          ]
          (target: {
            source = "${inputs.solforge-theme}/helix/${builtins.baseNameOf target}";
          });
    };
  };
}
