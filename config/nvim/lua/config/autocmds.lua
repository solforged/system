-- Keep wrap for prose, but leave spelling opt-in (`<leader>us`).
-- LazyVim enables both in the `lazyvim_wrap_spell` FileType autocmd.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_wrap_spell", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = false
  end,
})
