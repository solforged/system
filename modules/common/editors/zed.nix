# modules/common/editors/zed.nix
#
# The app comes from modules/nixos/editors/zed.nix or the darwin cask.
{ config, lib, ... }:

let
  cfg = config.modules.editors.zed;
in
{
  options.modules.editors.zed.enable = lib.mkEnableOption "Zed";

  config = lib.mkIf cfg.enable {
    # Only settings.json: Zed keeps other state in this directory.
    modules.dotfiles.configLink."zed/settings.json" = "zed/settings.json";
  };
}
