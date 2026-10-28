# modules/common/nh.nix
#
# nh runs rebuilds and shows what changed: `nh os switch` on NixOS,
# `nh darwin switch` on Macs. NH_FLAKE points it at the live checkout.
{ config, ... }:

{
  programs.nh = {
    enable = true;
    flake = config.modules.dotfiles.dir;
  };
}
