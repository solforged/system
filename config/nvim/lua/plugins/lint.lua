return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      local markdownlint = require("lint.linters.markdownlint-cli2")
      local parser = markdownlint.parser

      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = {
        args = { "--config", vim.fn.stdpath("config") .. "/.markdownlint.json", "-" },
        parser = function(output, bufnr)
          return vim.tbl_filter(function(diagnostic)
            return not (diagnostic.message or ""):find("MD013", 1, true)
          end, parser(output, bufnr))
        end,
      }
    end,
  },
}
