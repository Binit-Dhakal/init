-- ============================================================================
-- Markdown reading, two ways
-- ----------------------------------------------------------------------------
-- 1. render-markdown.nvim : renders markdown *inside* Neovim (headings, code
--    blocks, tables, bullets, checkboxes, callouts). The everyday reader — no
--    browser, works in the terminal with your catppuccin + truecolor setup.
--
--      <leader>mr -> toggle in-editor rendering on/off
--
-- 2. markdown-preview.nvim : opens a live GitHub-style preview in your BROWSER
--    (for images, mermaid diagrams, math). The backup for when you need full
--    fidelity.
--
--      <leader>mp -> toggle the browser preview
-- ============================================================================
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown", "md", "markdown.mdx" },
    opts = {
      render_modes = { "n", "c", "t" },
      -- Keep the cursor line rendered too (don't reveal raw markup on it).
      -- Better for READING: the line you're on stays pretty. Turn this back on
      -- (ignore = ...) if you ever want to edit raw syntax under the cursor.
      anti_conceal = { enabled = false },
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
        language_pad = 1,
      },
      bullet = {
        icons = { "●", "○", "◆", "◇" },
      },
      checkbox = {
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰱒 " },
      },
      dash = { width = 60 },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<cr>",
        { desc = "[M]arkdown [r]ender toggle (in-editor)" })
    end,
  },

  {
    "iamcco/markdown-preview.nvim",
    -- Build the plugin's bundled web app. Needs Node/npx available.
    build = "cd app && npx --yes yarn install",
    ft = { "markdown", "md", "markdown.mdx" },
    init = function()
      vim.g.mkdp_auto_close = 1       -- close the browser tab when you leave the buffer
      vim.g.mkdp_theme = "dark"
      vim.g.mkdp_echo_preview_url = 1 -- print the URL in case the browser doesn't auto-open
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown",
        desc = "[M]arkdown [p]review in browser" },
    },
  },
}
