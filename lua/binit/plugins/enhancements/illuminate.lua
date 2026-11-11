-- ============================================================================
-- vim-illuminate : highlight every occurrence of the symbol under the cursor
-- ----------------------------------------------------------------------------
-- Great while reviewing: put your cursor on a variable and instantly see
-- everywhere it is used in the file.
--   ]] / [[ -> jump to next / previous reference
-- ============================================================================
return {
  "RRethy/vim-illuminate",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    delay = 150,
    providers = { "lsp", "treesitter", "regex" },
    large_file_cutoff = 2000,
  },
  config = function(_, opts)
    require("illuminate").configure(opts)
    vim.keymap.set("n", "]]", function()
      require("illuminate").goto_next_reference(false)
    end, { desc = "Next reference" })
    vim.keymap.set("n", "[[", function()
      require("illuminate").goto_prev_reference(false)
    end, { desc = "Prev reference" })
  end,
}
