return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.json = { "dprint" }
      opts.formatters_by_ft.jsonc = { "dprint" }
      opts.formatters_by_ft.markdown = { "dprint" }
      opts.formatters_by_ft.objc = { "clang-format" }
      opts.formatters_by_ft.objcpp = { "clang-format" }

      opts.formatters = opts.formatters or {}
      opts.formatters.dprint = {
        command = "dprint",
        args = { "fmt", "--config-discovery=global", "--stdin", "$FILENAME" },
        stdin = true,
      }
    end,
  },
}
