-- ============================================================================
-- monaco_diff : open git diffs in the browser (Monaco diff editor)
-- ----------------------------------------------------------------------------
-- Day-to-day review stays in Neovim (Diffview). These keys are the "show me
-- this in the browser" escape hatch, using tools/monaco-diff/server.js.
--
--   <leader>gvd  uncommitted changes (working tree vs HEAD, incl. untracked)
--   <leader>gvm  this branch vs master (merge-base, like a PR "Files changed")
--   <leader>gvc  pick any commit (Telescope) -> that commit's diff
--
-- In the browser: click a file, or press n / p for next / previous file,
-- [ and ] for previous / next change. The server stops by itself once the tab
-- is closed.
-- ============================================================================
local M = {}

local script = vim.fn.stdpath("config") .. "/tools/monaco-diff/server.js"

local function find_node()
  local n = vim.fn.exepath("node")
  if n ~= "" then return n end
  -- nvm installs are often not on PATH when nvim is launched from a GUI/launcher
  local found = vim.fn.glob(vim.fn.expand("~/.nvm/versions/node/*/bin/node"), false, true)
  return found[#found]
end

-- Variables a browser launch needs. tmux can remove DISPLAY from a session
-- (when a client attaches without it), leaving panes unable to open a browser.
-- When one is missing, borrow it from tmux's global environment.
local DESKTOP_VARS = { "DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "DBUS_SESSION_BUS_ADDRESS", "XDG_CURRENT_DESKTOP" }

local function desktop_env()
  local env = {}
  if vim.fn.executable("tmux") == 0 then return env end
  for _, var in ipairs(DESKTOP_VARS) do
    if (vim.env[var] or "") == "" then
      local out = vim.fn.systemlist({ "tmux", "show-environment", "-g", var })
      local val = vim.v.shell_error == 0 and out[1] and out[1]:match("^" .. var .. "=(.+)$")
      if val then env[var] = val end
    end
  end
  return env
end

local function git_root()
  local dir = vim.fn.expand("%:p:h")
  if dir == "" or vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
    return nil
  end
  return out[1]
end

--- Start the diff server and open the browser.
--- @param mode "worktree"|"branch"|"commit"
--- @param sha string|nil   required for mode == "commit"
--- @param opts table|nil   { no_open = true, on_url = function(url) } (used by tests)
function M.open(mode, sha, opts)
  opts = opts or {}
  local node = find_node()
  if not node or node == "" then
    vim.notify("monaco-diff: node not found (install Node or fix PATH).", vim.log.levels.ERROR)
    return
  end
  local root = opts.root or git_root()
  if not root then
    vim.notify("monaco-diff: not inside a git repository.", vim.log.levels.WARN)
    return
  end

  local cmd = { node, script, "--repo", root, "--mode", mode }
  if sha then
    vim.list_extend(cmd, { "--sha", sha })
  end
  if opts.no_open then
    table.insert(cmd, "--no-open")
  end

  local state = { url = nil, connected = false, warned = false }
  local function warn_manual(why)
    if state.warned or state.connected then return end
    state.warned = true
    vim.notify("Monaco diff: " .. why .. "\nOpen this URL in your browser:\n" .. (state.url or "?"), vim.log.levels.WARN)
  end

  vim.system(cmd, {
    text = true,
    detach = true, -- keep serving even if nvim is closed; it exits on its own
    env = desktop_env(),
    stdout = function(_, data)
      if not data then return end
      for line in data:gmatch("[^\n]+") do
        local url = line:match("^MONACO_DIFF_URL (%S+)")
        local failed = line:match("^MONACO_DIFF_OPEN_FAILED (.*)$")
        vim.schedule(function()
          if url then
            state.url = url
            if opts.on_url then opts.on_url(url) end
            if not opts.no_open then
              vim.notify("Opening Monaco diff in your browser (" .. mode .. ")...", vim.log.levels.INFO)
              -- A browser that never loads the page is the usual failure, even if
              -- xdg-open itself reported success. Say so instead of staying silent.
              vim.defer_fn(function() warn_manual("the browser did not load the page within 12s.") end, 12000)
            end
          elseif failed then
            warn_manual("could not launch a browser (" .. failed .. ").")
          elseif line == "MONACO_DIFF_CONNECTED" then
            state.connected = true
            vim.notify("Monaco diff ready in browser (" .. mode .. ")", vim.log.levels.INFO)
          end
        end)
      end
    end,
  }, function(res)
    -- The process normally runs until the tab is closed. If it exits early,
    -- it is either "nothing to show" (3) or an error.
    if res.code ~= 0 then
      vim.schedule(function()
        local msg = vim.trim(res.stderr or "")
        if msg == "" then msg = "monaco-diff exited with code " .. res.code end
        vim.notify(msg, res.code == 3 and vim.log.levels.WARN or vim.log.levels.ERROR)
      end)
    end
  end)
end

--- Telescope commit picker; <CR> opens the chosen commit in the browser.
function M.pick_commit()
  local root = git_root()
  if not root then
    vim.notify("monaco-diff: not inside a git repository.", vim.log.levels.WARN)
    return
  end
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  require("telescope.builtin").git_commits({
    cwd = root,
    prompt_title = "Commit -> diff in browser (Monaco)",
    attach_mappings = function()
      actions.select_default:replace(function(bufnr)
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        if entry and entry.value then
          M.open("commit", entry.value, { root = root })
        end
      end)
      return true
    end,
  })
end

function M.setup()
  local map = vim.keymap.set
  map("n", "<leader>gvd", function() M.open("worktree") end,
    { desc = "[G]it [V]iew in browser: uncommitted [d]iff" })
  map("n", "<leader>gvm", function() M.open("branch") end,
    { desc = "[G]it [V]iew in browser: branch vs [m]aster" })
  map("n", "<leader>gvc", M.pick_commit,
    { desc = "[G]it [V]iew in browser: pick a [c]ommit" })
end

return M
