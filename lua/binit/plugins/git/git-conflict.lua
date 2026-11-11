-- ============================================================================
-- git-conflict.nvim : visual merge-conflict resolution
-- ----------------------------------------------------------------------------
-- Highlights conflict markers and gives one-key choices while reviewing
-- merges/rebases:
--   co -> choose ours      ct -> choose theirs
--   cb -> choose both      c0 -> choose none
--   ]x / [x -> jump between conflicts
--   <leader>gx -> list all conflicts in a quickfix list
-- ============================================================================
return {
  "akinsho/git-conflict.nvim",
  version = "*",
  event = "VeryLazy",
  opts = {
    default_mappings = true, -- co / ct / cb / c0 / ]x / [x
    disable_diagnostics = false,
    highlights = {
      incoming = "DiffAdd",
      current = "DiffText",
    },
  },
  config = function(_, opts)
    require("git-conflict").setup(opts)
    vim.keymap.set("n", "<leader>gx", "<cmd>GitConflictListQf<cr>", { desc = "[G]it conflicts in quickfi[x]" })
  end,
}
