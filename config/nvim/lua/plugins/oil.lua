return {
  "stevearc/oil.nvim",
  dependencies = { "nvim-mini/mini.icons" }, -- already shipped by LazyVim
  lazy = false, -- oil replaces netrw; must load before a dir buffer is opened
  opts = {
    default_file_explorer = true, -- take over netrw (snacks explorer disabled)
    delete_to_trash = true, -- matches yazi's trash-on-`d`
    view_options = {
      show_hidden = true,
    },
    -- Renames/moves/deletes are staged edits; commit them with :w.
    -- Directory buffer editing => bulk rename with vim motions, :%s, macros.
  },
  keys = {
    { "-", "<cmd>Oil<cr>", desc = "Open parent dir (oil)" },
    { "<leader>e", "<cmd>Oil<cr>", desc = "File manager (oil)" },
    -- Float = quick peek; press again (or <C-c>) to toggle shut. Leaves `q` free for macros.
    {
      "<leader>-",
      function()
        require("oil").toggle_float()
      end,
      desc = "File manager float (oil)",
    },
  },
}
