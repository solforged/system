# modules/common/shell/fnox.nix
#
# User-level secrets for projects, as age ciphertext decrypted with this
# host's ~/.config/fnox/age-identity.txt. System secrets belong to agenix.
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
    modules.dotfiles.configLink."fnox/config.toml" = "fnox/config.toml";
  };
}
