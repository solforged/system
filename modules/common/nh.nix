# modules/common/nh.nix
#
# nh runs rebuilds and shows what changed: `nh os switch` on NixOS,
# `nh darwin switch` on Macs. NH_FLAKE points it at the live checkout; a flake
# that builds hosts through lib.mkHost can point it at itself.
{ config, lib, ... }:

{
  programs.nh = {
    enable = true;
    flake = lib.mkDefault config.modules.dotfiles.dir;
  };
}
