# modules/nixos/editors/nvim.nix
#
# Tree-sitter builds parsers with GCC on NixOS.
# macOS uses clang from the Xcode Command Line Tools.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf config.modules.editors.nvim.enable {
    # The clang wrapper (apps.workstation-tools) also ships cc, c++, cpp
    # and ld; GCC keeps them, as on most Linux systems.
    hm.home.packages = [ (lib.hiPrio pkgs.gcc) ];
  };
}
