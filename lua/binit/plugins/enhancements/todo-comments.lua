-- ============================================================================
-- todo-comments.nvim : highlight & search TODO / FIXME / HACK / NOTE / WARN
-- ----------------------------------------------------------------------------
-- When reviewing AI-generated code, it often leaves TODO/FIXME placeholders.
-- This surfaces them clearly and lets you list them all.
--   ]t / [t     -> jump between todo comments
--   <leader>st  -> search all todos (Telescope)
--   <leader>xt  -> open todos in the Trouble panel
-- ============================================================================
return {
  "folke/todo-comments.nvim",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    signs = true,
  },
  config = function(_, opts)
    local todo = require("todo-comments")
    todo.setup(opts)
    vim.keymap.set("n", "]t", function() todo.jump_next() end, { desc = "Next todo comment" })
    vim.keymap.set("n", "[t", function() todo.jump_prev() end, { desc = "Prev todo comment" })
    vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "[S]earch [T]odos" })
    vim.keymap.set("n", "<leader>xt", "<cmd>TodoTrouble<cr>", { desc = "Todos in Trouble" })
  end,
}
