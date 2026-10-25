# modules/common/shell/atuin.nix
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.atuin;
in
{
  options.modules.shell.atuin.enable = lib.mkEnableOption "Atuin shell history";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.atuin ];
    modules.dotfiles.configLink."atuin/config.toml" = "atuin/config.toml";
  };
}
