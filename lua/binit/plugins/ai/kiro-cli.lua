-- ============================================================================
-- kiro-cli integration (via toggleterm.nvim)
-- ----------------------------------------------------------------------------
-- Your AI is the kiro-cli terminal agent, not an in-editor LLM. So instead of
-- a chat plugin, we run kiro-cli in a terminal INSIDE Neovim, right next to the
-- Diffview review pane. Edit/review on one side, talk to kiro-cli on the other,
-- and use <leader>gd (Diffview) to see exactly what it changed.
--
-- WORKFLOW:
--   <leader>ak -> toggle the kiro-cli terminal (vertical split on the right)
--   <leader>af -> toggle a floating kiro-cli terminal
--   <leader>ap -> send the path of the current file to kiro-cli (to ask about it)
--   <leader>ad -> send "review this diff" + the git diff into kiro-cli
--   <leader>as -> (visual) send the selected lines into the kiro-cli terminal
--   <C-\>      -> quick toggle of a plain terminal
--
-- In terminal mode, press <Esc><Esc> to get back to normal mode, then the
-- window-nav keys (<C-h/j/k/l>) work as usual.
-- ============================================================================
return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec" },
  keys = {
    { "<C-\\>", desc = "Toggle terminal" },
    { "<leader>ak", desc = "[A]I: toggle [k]iro-cli" },
    { "<leader>af", desc = "[A]I: [f]loating kiro-cli" },
    { "<leader>aR", desc = "[A]I: [R]esume kiro session (pick)" },
    { "<leader>aL", desc = "[A]I: resume [L]ast kiro session" },
    { "<leader>aN", desc = "[A]I: [N]ew kiro session" },
    { "<leader>ap", desc = "[A]I: send file [p]ath to kiro" },
    { "<leader>ad", desc = "[A]I: send git [d]iff to kiro" },
    { "<leader>as", mode = "v", desc = "[A]I: [s]end selection to kiro" },
  },
  config = function()
    require("toggleterm").setup({
      open_mapping = [[<C-\>]],
      direction = "horizontal",
      size = 15,
      shade_terminals = true,
      start_in_insert = true,
      persist_mode = true,
      -- In terminal mode, <Esc><Esc> drops you to normal mode
      on_open = function()
        vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = 0, silent = true })
      end,
    })

    local Terminal = require("toggleterm.terminal").Terminal

    -- A dedicated, persistent kiro-cli terminal (vertical, right side)
    local function new_kiro_side(cmd)
      return Terminal:new({
        cmd = cmd,
        direction = "vertical",
        hidden = true,
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = term.bufnr, silent = true })
          vim.keymap.set("t", "<C-q>", function() term:toggle() end, { buffer = term.bufnr, silent = true })
        end,
      })
    end
    local kiro = new_kiro_side("kiro-cli chat")

    -- A floating kiro-cli terminal for a quick, full-screen conversation
    local function new_kiro_float(cmd)
      return Terminal:new({
        cmd = cmd,
        direction = "float",
        hidden = true,
        float_opts = { border = "curved", width = function() return math.floor(vim.o.columns * 0.85) end,
          height = function() return math.floor(vim.o.lines * 0.85) end },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { buffer = term.bufnr, silent = true })
          -- Hide the float without leaving terminal mode (session keeps running)
          vim.keymap.set("t", "<C-q>", function() term:toggle() end, { buffer = term.bufnr, silent = true })
          vim.keymap.set("n", "q", function() term:toggle() end, { buffer = term.bufnr, silent = true })
          -- Auto-close the float the moment it loses focus (switching window,
          -- buffer or tab). This prevents the "visible but unfocused / frozen"
          -- float that happens after leaving and coming back. Re-open with
          -- <leader>af and it comes back cleanly focused with the same session.
          vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
            buffer = term.bufnr,
            callback = function()
              if term:is_open() then
                term:close()
              end
            end,
          })
        end,
      })
    end
    local kiro_float = new_kiro_float("kiro-cli chat")

    -- Open the float and guarantee the cursor is IN it, in insert mode.
    -- If a stale float window is somehow still around, close it first so the
    -- reopen is always a clean, focused window you can type in.
    local function open_float_focused()
      if kiro_float:is_open() then
        -- already open: just make sure we're focused and in insert mode
        local win = kiro_float.window
        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_set_current_win(win)
          vim.cmd("startinsert!")
          return
        end
        kiro_float:close()
      end
      kiro_float:open()
      vim.cmd("startinsert!")
    end

    -- Replace the floating terminal with one running a different kiro command
    -- (used by the resume keymaps). The old kiro process is closed; kiro
    -- saves its conversation, so it can be resumed again later.
    local function restart_kiro(cmd)
      kiro_float:shutdown()
      kiro_float = new_kiro_float(cmd)
      kiro_float:open()
      vim.cmd("startinsert!")
    end

    -- Helper: make sure the side terminal is open, then send text to it.
    local function send_to_kiro(text)
      if not kiro:is_open() then
        kiro:open()
      end
      -- Give the shell a beat to be ready, then paste the text (no auto-enter,
      -- so you can review/edit the prompt before submitting).
      vim.defer_fn(function()
        kiro:send(text, false)
      end, 150)
    end

    -- Keymaps
    local map = vim.keymap.set
    map("n", "<leader>ak", function() kiro:toggle() end, { desc = "[A]I: toggle [k]iro-cli" })
    map("n", "<leader>af", function()
      -- If the float is genuinely open and showing a valid window, this is a
      -- "hide" press. Otherwise (closed, or stale/stuck) open it focused.
      if kiro_float:is_open() and kiro_float.window and vim.api.nvim_win_is_valid(kiro_float.window) then
        kiro_float:close()
      else
        open_float_focused()
      end
    end, { desc = "[A]I: [f]loating kiro-cli" })

    map("n", "<leader>aR", function() restart_kiro("kiro-cli chat --resume-picker") end,
      { desc = "[A]I: [R]esume kiro session (pick)" })
    map("n", "<leader>aL", function() restart_kiro("kiro-cli chat --resume") end,
      { desc = "[A]I: resume [L]ast kiro session" })
    map("n", "<leader>aN", function() restart_kiro("kiro-cli chat") end,
      { desc = "[A]I: [N]ew kiro session" })

    map("n", "<leader>ap", function()
      local path = vim.fn.expand("%:p")
      if path == "" then
        vim.notify("Current buffer has no file path.", vim.log.levels.WARN)
        return
      end
      send_to_kiro("Take a look at this file: " .. path .. " ")
    end, { desc = "[A]I: send file [p]ath to kiro" })

    map("n", "<leader>ad", function()
      local diff = vim.fn.system("git diff HEAD")
      if vim.v.shell_error ~= 0 or vim.trim(diff) == "" then
        vim.notify("No git diff to review (nothing changed vs HEAD).", vim.log.levels.WARN)
        return
      end
      -- kiro-cli reads the repo itself, so point it at the diff rather than
      -- pasting a huge blob into the terminal.
      send_to_kiro("Review my current uncommitted changes (git diff HEAD). "
        .. "Point out bugs, security issues, and edge cases, concisely. ")
    end, { desc = "[A]I: send git [d]iff to kiro" })

    map("v", "<leader>as", function()
      -- Grab the current visual selection
      local save = vim.fn.getreg('"')
      vim.cmd('noautocmd normal! "vy')
      local sel = vim.fn.getreg("v")
      vim.fn.setreg('"', save)
      send_to_kiro("Here is some code I want you to review:\n" .. sel .. "\n")
    end, { desc = "[A]I: [s]end selection to kiro" })
  end,
}
