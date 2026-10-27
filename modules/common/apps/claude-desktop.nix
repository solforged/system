# modules/common/apps/claude-desktop.nix
#
# The app comes from modules/nixos/apps/claude-desktop.nix or the darwin cask.
{ lib, ... }:

{
  options.modules.apps.claude-desktop.enable = lib.mkEnableOption "Claude Desktop";
}
