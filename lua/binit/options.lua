vim.opt.clipboard = '' -- use system clipboard
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.mouse = 'a'    -- allow the mouse to be used in Nvim

-- Tab
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- UIConfig
vim.opt.termguicolors = true  -- enable 24-bit truecolor (required by catppuccin,
                              -- diffview, and gui= highlight attributes). Ghostty,
                              -- tmux and most modern terminals support this.
vim.opt.number = true         -- show absolute number
vim.opt.relativenumber = true -- add number to each line on left side

-- Prettier diffs: histogram algorithm reads more naturally, linematch aligns
-- changed lines, and a diagonal fill char beats the default '-' for deleted
-- regions. These affect :diffthis, gitsigns diff, and Diffview.
vim.opt.diffopt = {
  'internal', 'filler', 'closeoff',
  'algorithm:histogram',
  'linematch:60',
  'indent-heuristic',
}
vim.opt.fillchars:append({ diff = '╱' })
vim.opt.cursorline = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.showmode = true


-- Searching
vim.opt.incsearch = true  -- search as characters are entered
vim.opt.hlsearch = false  -- donot highlight matches
vim.opt.ignorecase = true -- ignore case in searches by default
vim.opt.smartcase = true  -- but make it case sensitive if uppercase is entered

vim.api.nvim_create_user_command('Exec', function()
    vim.cmd('set splitbelow')
    vim.cmd('new')
    vim.cmd('set filetype=sh')
    vim.cmd('read !sh #')
end, {})
