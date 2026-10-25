# modules/common/shell/fnox.nix
#
# User-level secrets for projects. With Proton Pass enabled, fnox reads them
# from Proton Pass through pass-cli; system secrets belong to agenix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.fnox;
in
{
  options.modules.shell.fnox.enable = lib.mkEnableOption "fnox";

  config = lib.mkIf cfg.enable {
    hm.home.packages = [ pkgs.fnox ];
    modules.dotfiles.configLink = lib.mkIf config.modules.apps.proton-pass.enable {
      "fnox/config.toml" = "fnox/config.toml";
    };
  };
}
