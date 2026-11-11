-- ============================================================================
-- diffview.nvim : the main tool for REVIEWING code changes
-- ----------------------------------------------------------------------------
-- Opens a full-tab, side-by-side diff of your working tree, a commit, a branch
-- comparison, or a single file's entire history. This is the primary way to
-- review what you (or an AI assistant) changed before committing.
--
-- Review flows this gives you:
--   * <leader>gd  -> review ALL uncommitted changes (working tree vs HEAD)
--   * <leader>gh  -> browse the history of the whole repo
--   * <leader>gH  -> history of the current file
--   * :DiffviewOpen main...HEAD -> review a whole branch vs main (PR-style)
-- ============================================================================
return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewFileHistory",
  },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "[G]it [D]iff: review working-tree changes" },
    { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "[G]it [D]iff close" },
    { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "[G]it [H]istory of repo" },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "[G]it history of current file" },
    { "<leader>gL", desc = "[G]it [L]ine history" },
    { "<leader>gL", mode = "v", desc = "[G]it [L]ine history (selection)" },
    -- Review a whole branch against main/master, like reviewing a PR locally
    {
      "<leader>gm",
      function()
        local base = vim.fn.input("Diff against (branch/commit): ", "master")
        if base ~= "" then
          vim.cmd("DiffviewOpen " .. base .. "...HEAD")
        end
      end,
      desc = "[G]it review branch vs [m]ain",
    },
  },
  opts = {
    enhanced_diff_hl = true, -- richer inline highlighting of changed words
    view = {
      -- Show changes in a classic side-by-side split
      default = { layout = "diff2_horizontal" },
      -- When reviewing merges, show both parents
      merge_tool = {
        layout = "diff3_mixed",
        disable_diagnostics = true,
      },
      file_history = { layout = "diff2_horizontal" },
    },
    file_panel = {
      listing_style = "tree",
      win_config = { position = "left", width = 35 },
    },
    keymaps = {
      view = {
        { "n", "<tab>", "<cmd>DiffviewToggleFiles<cr>", { desc = "Toggle file panel" } },
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close review" } },
      },
      file_panel = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close review" } },
      },
    },
  },
  config = function(_, opts)
    require("diffview").setup(opts)

    -- Full history of a line (git log -L). Opens Diffview's file-history
    -- panel as a left sidebar, like fugitive's blame.
    local function line_history(l1, l2)
      local file = vim.fn.expand("%:p")
      if file == "" then
        vim.notify("Current buffer has no file.", vim.log.levels.WARN)
        return
      end
      -- Diffview wants the path relative to the repo/cwd.
      local rel = vim.fn.fnamemodify(file, ":.")
      vim.cmd(string.format("DiffviewFileHistory --follow -L%d,%d:%s", l1, l2, vim.fn.fnameescape(rel)))
    end

    vim.keymap.set("n", "<leader>gL", function()
      local l = vim.fn.line(".")
      line_history(l, l)
    end, { desc = "[G]it [L]ine history (current line)" })

    vim.keymap.set("v", "<leader>gL", function()
      local l1 = vim.fn.line("v")
      local l2 = vim.fn.line(".")
      if l1 > l2 then l1, l2 = l2, l1 end
      line_history(l1, l2)
    end, { desc = "[G]it [L]ine history (selection)" })
  end,
}
