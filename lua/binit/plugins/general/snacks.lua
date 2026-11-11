-- ============================================================================
-- snacks.nvim : used here ONLY for its image module
-- ----------------------------------------------------------------------------
-- Renders images inside Neovim using the Kitty graphics protocol (Ghostty
-- supports it). Works inside tmux because tmux has `allow-passthrough on`.
--
--   * Open a .png/.jpg/.gif/.webp file  -> it is shown as an image
--   * Markdown files                    -> ![alt](image.png) renders inline
--   * <leader>mi                        -> show the image under the cursor in
--                                          a floating window (markdown links)
--
-- Needs ImageMagick (`magick`) installed for conversion/resizing.
-- Every other snacks module stays disabled (they are off by default).
-- ============================================================================
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    image = {
      enabled = true,
      doc = {
        enabled = true, -- render images found in markdown/other docs
        inline = true,  -- draw them in the buffer (falls back to float if unsupported)
        float = true,   -- show a float for the image under the cursor
      },
    },
  },
  keys = {
    {
      "<leader>mi",
      function() require("snacks").image.hover() end,
      desc = "[M]arkdown [i]mage preview (under cursor)",
    },
  },
}
