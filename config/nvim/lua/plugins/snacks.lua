return {
  "folke/snacks.nvim",
  -- Drop the tree explorer; navigate via pickers, manipulate files via oil.nvim.
  opts = {
    explorer = { enabled = false },
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
