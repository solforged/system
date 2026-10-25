return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      for name, server in pairs(opts.servers) do
        if server == true then
          opts.servers[name] = { mason = false }
        elseif type(server) == "table" then
          server.mason = false
        end
      end
    end,
  },
}
