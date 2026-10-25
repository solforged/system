return {
  {
    "iamcco/markdown-preview.nvim",
    -- Nix provides the preview server and its Node dependencies.
    dir = vim.env.NVIM_MARKDOWN_PREVIEW,
    build = false,
  },
}
