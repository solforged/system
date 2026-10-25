# modules/common/editors/helix.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.editors.helix;
in
{
  options.modules.editors.helix.enable = lib.mkEnableOption "Helix";

  config = lib.mkIf cfg.enable {
    hm.home.packages = with pkgs; [
      helix
      # Language servers named in config/helix/languages.toml
      marksman
      pyright
      ruff
      taplo
    ];
    modules.dotfiles.configLink.helix = "helix";
  };
}
