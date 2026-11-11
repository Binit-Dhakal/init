vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath
  }
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup(
  {
    -- Core UI
    { import = "binit.plugins.ui" },
    -- General editing (telescope, file tree, navigation)
    { import = "binit.plugins.general" },
    -- LSP, completion, formatting
    { import = "binit.plugins.lsp" },
    -- Tools (DAP debugger, DB UI, etc.)
    { import = "binit.plugins.tools" },
    -- Editing enhancements (autopairs, illuminate, todo, trouble, etc.)
    { import = "binit.plugins.enhancements" },
    -- Git / Diff / Code review
    { import = "binit.plugins.git" },
    -- AI code review & assistant
    { import = "binit.plugins.ai" },
    -- Misc / custom autocommands
    { import = "binit.customs" },
  },
  {
    install = {
      colorscheme = { "catppuccin" },
    },
    checker = {
      enabled = true,
      notify = false,
    },
    change_detection = {
      notify = false,
    },
    performance = {
      rtp = {
        disabled_plugins = {
          "gzip", "matchit", "matchparen", "netrwPlugin",
          "tarPlugin", "tohtml", "tutor", "zipPlugin",
        },
      },
    },
  }
)
