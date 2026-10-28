{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.fonts.nerdSymbols.enable = lib.mkEnableOption "Symbols Nerd Font";
  config = lib.mkIf config.modules.fonts.nerdSymbols.enable {
    fonts.packages = [ pkgs.nerd-fonts.symbols-only ];
  };
}
