-- ============================================================================
-- neogit : a full git UI inside Neovim (magit-style)
-- ----------------------------------------------------------------------------
-- One buffer to see status, stage/unstage hunks, write commits, push/pull,
-- manage branches, and open diffs. Integrates with diffview.nvim so pressing
-- "d" on a file opens the rich diff viewer.
--
--   <leader>gg -> open the git status / control panel
--   <leader>gc -> jump straight to the commit screen
-- ============================================================================
return {
  "NeogitOrg/neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "sindrets/diffview.nvim",
    "nvim-telescope/telescope.nvim",
  },
  cmd = "Neogit",
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "[G]it status (Neo[g]it)" },
    { "<leader>gc", "<cmd>Neogit commit<cr>", desc = "[G]it [C]ommit" },
    { "<leader>gp", "<cmd>Neogit pull<cr>", desc = "[G]it [P]ull" },
    { "<leader>gP", "<cmd>Neogit push<cr>", desc = "[G]it [P]ush" },
    { "<leader>gb", "<cmd>Telescope git_branches<cr>", desc = "[G]it [B]ranches" },
  },
  opts = {
    integrations = {
      diffview = true,
      telescope = true,
    },
    graph_style = "unicode",
    signs = {
      hunk = { "", "" },
      item = { "", "" },
      section = { "", "" },
    },
  },
}
