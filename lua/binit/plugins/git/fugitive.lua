-- ============================================================================
-- vim-fugitive : the classic git command wrapper
-- ----------------------------------------------------------------------------
-- Useful alongside Neogit/Diffview for quick one-off commands and blame.
--   <leader>gs -> :Git (status)
--   <leader>gl -> :Git log (oneline graph)
--   <leader>gB -> :Git blame for the current file
-- ============================================================================
return {
  "tpope/vim-fugitive",
  cmd = { "Git", "G" },
  keys = {
    { "<leader>gs", "<cmd>Git<cr>", desc = "[G]it [S]tatus (fugitive)" },
    { "<leader>gl", "<cmd>Git log --oneline --graph --decorate<cr>", desc = "[G]it [L]og" },
    { "<leader>gB", "<cmd>Git blame<cr>", desc = "[G]it [B]lame file" },
  },
}
