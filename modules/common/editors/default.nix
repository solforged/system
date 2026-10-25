# modules/common/editors/default.nix
{
  config,
  lib,
  my,
  ...
}:

let
  cfg = config.modules.editors;
in
{
  options.modules.editors.default = my.mkOpt (lib.types.nullOr lib.types.str) null;

  config = lib.mkIf (cfg.default != null) {
    modules.env.variables.EDITOR = cfg.default;
  };
}
