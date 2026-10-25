# modules/common/shell/mise.nix
#
# mise manages tools and tasks declared by individual projects.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.mise;
in
{
  options.modules.shell.mise.enable = lib.mkEnableOption "mise";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.mise ];
    modules.dotfiles.configLink."mise/config.toml" = "mise/config.toml";
    modules.env = {
      variables.MISE_EXPERIMENTAL = "1";
      # Shims resolve project tools for non-interactive callers in the project directory.
      path = [ "$HOME/.local/share/mise/shims" ];
    };
  };
}
