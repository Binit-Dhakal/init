return {
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  'lewis6991/gitsigns.nvim',
  config = function()
    local gs = require("gitsigns")

    gs.setup {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
      word_diff = true,

      -- Auto-on inline blame: shows author · time-ago · summary at end of the
      -- line the cursor is on (like a lightweight, always-visible git blame).
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = 'eol',
        delay = 300,
        ignore_whitespace = true,
      },
      current_line_blame_formatter = '  <author> · <author_time:%Y-%m-%d> · <summary>',

      on_attach = function(bufnr)
        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map({ 'n', 'v' }, ']c', function()
          if vim.wo.diff then
            return ']c'
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, desc = 'Jump to next hunk' })

        map({ 'n', 'v' }, '[c', function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, desc = 'Jump to previous hunk' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'stage git hunk' })
        map('v', '<leader>hr', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'reset git hunk' })
        -- normal mode
        map('n', '<leader>hs', gs.stage_hunk, { desc = 'git stage hunk' })
        map('n', '<leader>hr', gs.reset_hunk, { desc = 'git reset hunk' })
        map('n', '<leader>hS', gs.stage_buffer, { desc = 'git Stage buffer' })
        map('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'undo stage hunk' })
        map('n', '<leader>hR', gs.reset_buffer, { desc = 'git Reset buffer' })
        map('n', '<leader>hp', gs.preview_hunk, { desc = 'preview git hunk' })
        map('n', '<leader>hb', function()
          gs.blame_line { full = false }
        end, { desc = 'git blame line' })
        map('n', '<leader>hP', function()
          -- Blame the current line -> its commit -> the PR that merged it ->
          -- open that PR in the browser (needs the `gh` CLI, GitHub only).
          local file = vim.fn.expand('%:p')
          local line = vim.fn.line('.')
          if file == '' then
            vim.notify('No file for this buffer.', vim.log.levels.WARN)
            return
          end
          local dir = vim.fn.fnamemodify(file, ':h')
          -- -w = ignore whitespace, -L n,n = just this line, --porcelain for parsing
          local blame = vim.fn.systemlist(
            string.format('git -C %s blame -w -L %d,%d --porcelain -- %s',
              vim.fn.shellescape(dir), line, line, vim.fn.shellescape(file)))
          if vim.v.shell_error ~= 0 or #blame == 0 then
            vim.notify('git blame failed for this line.', vim.log.levels.ERROR)
            return
          end
          local sha = blame[1]:match('^(%x+)')
          if not sha then
            vim.notify('Could not parse commit from blame.', vim.log.levels.ERROR)
            return
          end
          if sha:match('^0+$') then
            vim.notify('This line is a local, uncommitted change.', vim.log.levels.WARN)
            return
          end
          vim.notify('Finding PR for ' .. sha:sub(1, 8) .. ' ...', vim.log.levels.INFO)
          -- Ask GitHub which PR contained this commit, take the first, open it.
          vim.system(
            { 'sh', '-c', string.format(
              "cd %s && gh pr list --search %s --state all --json url,number --jq '.[0].url'",
              vim.fn.shellescape(dir), vim.fn.shellescape(sha)) },
            { text = true },
            function(res)
              vim.schedule(function()
                local url = vim.trim(res.stdout or '')
                if res.code ~= 0 or url == '' or url == 'null' then
                  vim.notify('No merged PR found for commit ' .. sha:sub(1, 8)
                    .. '. Opening the commit instead.', vim.log.levels.WARN)
                  -- Fallback: open the commit page on GitHub.
                  vim.system({ 'sh', '-c', string.format(
                    'cd %s && gh browse %s', vim.fn.shellescape(dir), sha) })
                  return
                end
                vim.ui.open(url)
                vim.notify('Opening ' .. url, vim.log.levels.INFO)
              end)
            end)
        end, { desc = 'git blame line -> open [P]R in browser' })
        map('n', '<leader>hd', gs.diffthis, { desc = 'git diff against index' })
        map('n', '<leader>hD', function()
          gs.diffthis '~'
        end, { desc = 'git diff against last commit' })
        map('n', '<leader>hm', function()
          -- Show the current file diffed against master, so you can see what
          -- THIS line looked like on master (and everything else that changed).
          local base = vim.fn.systemlist('git rev-parse --verify --quiet master')[1]
          if not base or base == '' then base = 'main' else base = 'master' end
          gs.diffthis(base)
        end, { desc = 'git diff current file vs master' })

        -- Toggles
        map('n', '<leader>tb', gs.toggle_current_line_blame, { desc = 'toggle git blame line' })
        map('n', '<leader>td', gs.toggle_deleted, { desc = 'toggle git show deleted' })

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'select git hunk' })
      end,
    }
  end,
}
