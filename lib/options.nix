# lib/options.nix
{ lib, ... }:

{
  # mkOpt :: type -> default -> option
  mkOpt = type: default: lib.mkOption { inherit type default; };

  # mkOpt' :: type -> default -> description -> option
  mkOpt' =
    type: default: description:
    lib.mkOption { inherit type default description; };

  # mkBoolOpt :: bool -> option
  mkBoolOpt =
    default:
    lib.mkOption {
      inherit default;
      type = lib.types.bool;
      example = true;
    };
}
