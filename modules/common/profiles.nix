# modules/common/profiles.nix
#
# Profiles name what a host is. Profile modules match on these strings, as in
# hlissner's dotfiles: modules/nixos/profiles/hardware/gpu/nvidia.nix applies
# when "gpu/nvidia" is in modules.profiles.hardware.
{ lib, my, ... }:

let
  inherit (lib) types;
in
{
  options.modules.profiles = {
    role = my.mkOpt (types.nullOr (
      types.enum [
        "workstation"
        "server"
      ]
    )) null;
    hardware = my.mkOpt (types.listOf types.str) [ ];
  };
}
