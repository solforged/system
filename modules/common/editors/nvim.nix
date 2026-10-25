# modules/common/editors/nvim.nix
#
# LazyVim keeps plugins in lazy-lock.json. Nix provides its language tools.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.editors.nvim;
in
{
  options.modules.editors.nvim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf cfg.enable {
    hm.home.packages = with pkgs; [
      neovim
      fd
      ripgrep
      tree-sitter
      lua-language-server
      stylua
      shfmt
      fish
      clang-tools
      neocmakelsp
      cmake
      cmake-format
      cmake-lint
      vscode-langservers-extracted
      marksman
      markdownlint-cli2
      markdown-toc
      prettier
      pyright
      ruff
      rust-analyzer
      taplo
      yaml-language-server
      dprint
      # modules.dev.node's version wins when both are on.
      (lib.lowPrio nodejs)
    ];
    modules.dotfiles.configLink.nvim = "nvim";
    modules.env.variables.NVIM_MARKDOWN_PREVIEW = "${pkgs.vimPlugins.markdown-preview-nvim}";
  };
}
