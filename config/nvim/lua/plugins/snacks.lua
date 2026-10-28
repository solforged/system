return {
  "folke/snacks.nvim",
  -- Drop the tree explorer; navigate via pickers, manipulate files via oil.nvim.
  opts = {
    explorer = { enabled = false },
    -- Terminals open nu. vim.o.shell stays $SHELL (zsh) for :! and plugins.
    terminal = {
      shell = vim.fn.executable("nu") == 1 and "nu" or nil,
    },
    picker = {
      sources = {
        explorer = {
          hidden = true,
        },
        files = {
          hidden = true,
        },
        grep = {
          hidden = true,
        },
      },
    },
  },
  -- Unbind LazyVim's snacks-explorer keys (from extras/editor/snacks_explorer.lua).
  keys = {
    { "<leader>e", false },
    { "<leader>E", false },
    { "<leader>fe", false },
    { "<leader>fE", false },
  },
}
