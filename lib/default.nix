# lib/default.nix
#
# Builds `my`, the helper set every module receives as a module argument.
{ lib, inputs }:

let
  my = lib.foldr (file: acc: acc // import file { inherit lib inputs my; }) { } [
    ./options.nix
    ./modules.nix
    ./hosts.nix
  ];
in
my
