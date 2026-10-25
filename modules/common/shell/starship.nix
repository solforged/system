# modules/common/shell/starship.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.starship;
in
{
  options.modules.shell.starship.enable = lib.mkEnableOption "Starship prompt";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.starship ];
    modules.dotfiles.configLink."starship.toml" = "starship.toml";
  };
}
