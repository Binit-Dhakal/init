-- ============================================================================
-- trouble.nvim : a pretty, navigable list of diagnostics / references / quickfix
-- ----------------------------------------------------------------------------
-- A clean panel to review all problems in the code at once — ideal for
-- vetting AI-generated changes that may introduce errors.
--   <leader>xx -> workspace diagnostics
--   <leader>xX -> diagnostics for the current buffer only
--   <leader>xq -> quickfix list
--   <leader>xl -> location list
--   <leader>xr -> LSP references for symbol under cursor
-- ============================================================================
return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {
    focus = true,
  },
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (workspace)" },
    { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (buffer)" },
    { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
    { "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
    { "<leader>xr", "<cmd>Trouble lsp_references toggle<cr>", desc = "LSP references" },
    { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols outline" },
  },
}
