local config = require "vsterm.config"
local state = require "vsterm.state"

local M = {}

local main_win = nil
local term_list_win = nil
local term_list_buf = nil
local original_win = nil -- Store the window we came from
local help_win = nil
local help_buf = nil

---Focus the main terminal window and start insert mode
---@param term_id number|nil Terminal ID to focus (current if nil)
function M.focus_terminal(term_id)
  main_win = M.get_main_window()
  if main_win and vim.api.nvim_win_is_valid(main_win) then
    vim.api.nvim_set_current_win(main_win)

    -- Start insert mode if we're in a terminal
    local current_id = term_id or state.get_current_terminal()
    if current_id then
      local term = state.get_terminal(current_id)
      if term and term.bufnr and vim.api.nvim_get_option_value("buftype", { buf = term.bufnr }) == "terminal" then
        vim.cmd "startinsert"
      end
    end
  end
end

---Apply standardized window options
---@param win number Window ID
local function apply_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  pcall(vim.api.nvim_set_option_value, "number", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "relativenumber", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "signcolumn", "no", { win = win })
  pcall(vim.api.nvim_set_option_value, "foldcolumn", "0", { win = win })
  pcall(vim.api.nvim_set_option_value, "wrap", false, { win = win })
end

---Create or update terminal buffer in main window
---@param term Terminal Terminal object
local function ensure_terminal_buffer(term)
  if
    (not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr))
    and main_win
    and vim.api.nvim_win_is_valid(main_win)
  then
    -- Create a fresh buffer for the terminal
    local bufnr = vim.api.nvim_create_buf(false, true)

    -- Set the buffer in the main window first
    vim.api.nvim_win_set_buf(main_win, bufnr)

    -- Switch to main window to start terminal
    local old_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(main_win)

    -- Start terminal in the fresh buffer
    term.job_id = vim.fn.termopen(config.options.shell or vim.o.shell)
    term.bufnr = bufnr

    -- Set buffer options
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = term.bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = term.bufnr })

    -- Set up terminal-specific keymaps
    local api = require "vsterm.api"
    api.set_terminal_keymaps()

    -- Go back to original window
    vim.api.nvim_set_current_win(old_win)
  else
    -- Set window to use the existing terminal buffer
    vim.api.nvim_win_set_buf(main_win, term.bufnr)
  end
end

---Set up dynamic keymaps for terminal switching
local function setup_terminal_keymaps()
  if config.options.number_prefix then
    local terminals = state.get_terminals()
    -- Clear existing number mappings
    for i = 1, 9 do
      local key = config.options.number_prefix .. i
      pcall(vim.keymap.del, "n", config.t(key))
    end

    -- Create new mappings for existing terminals
    for i, term in ipairs(terminals) do
      if i <= 9 then
        local key = config.options.number_prefix .. i
        vim.keymap.set("n", config.t(key), function()
          state.set_current_terminal(term.id)
          M.refresh()
          if state.is_visible() then
            M.focus_terminal(term.id)
          end
        end, { silent = true, desc = "Switch to terminal " .. i })
      end
    end
  end
end

---Get terminal at current line in terminal list
---@return number|nil terminal_id
local function get_terminal_at_line(line_num)
  local terminals = state.get_terminals()
  local terminal_idx = line_num or vim.fn.line "."
  if terminal_idx >= 1 and terminal_idx <= #terminals then
    return terminals[terminal_idx].id
  end
  return nil
end

---Setup keymaps for terminal list
local function setup_terminal_list_keymaps()
  if not term_list_buf then
    return
  end

  -- Mouse support
  if config.options.enable_mouse then
    vim.keymap.set("n", "<LeftMouse>", function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid == term_list_win then
        local term_id = get_terminal_at_line(mouse.line)
        if term_id then
          state.set_current_terminal(term_id)
          M.refresh()
          M.focus_terminal(term_id)
        end
      end
    end, { buffer = term_list_buf, silent = true })
  end

  -- Keyboard shortcuts
  vim.keymap.set("n", "<CR>", function()
    local term_id = get_terminal_at_line()
    if term_id then
      state.set_current_terminal(term_id)
      M.refresh()
      M.focus_terminal(term_id)
    end
  end, { buffer = term_list_buf, silent = true })

  vim.keymap.set("n", "d", function()
    local term_id = get_terminal_at_line()
    if term_id then
      local api = require "vsterm.api"
      api.kill_terminal(term_id)
    end
  end, { buffer = term_list_buf, silent = true })

  vim.keymap.set("n", "r", function()
    local term_id = get_terminal_at_line()
    if term_id then
      vim.ui.input({ prompt = "New terminal name: " }, function(name)
        if name then
          local api = require "vsterm.api"
          api.rename_terminal(name, term_id)
        end
      end)
    end
  end, { buffer = term_list_buf, silent = true })

  vim.keymap.set("n", "n", function()
    local api = require "vsterm.api"
    api.create_terminal()
  end, { buffer = term_list_buf, silent = true })

  vim.keymap.set("n", "?", function()
    M.show_help()
  end, { buffer = term_list_buf, silent = true })
end

---Create the main terminal window layout
local function create_layout()
  -- Save current window
  local current_win = vim.api.nvim_get_current_win()

  -- Calculate dimensions
  local ui_height = math.floor(vim.o.lines * config.options.height)

  -- Step 1: Create bottom horizontal split
  vim.cmd(string.format("botright %dsplit", ui_height))

  -- Immediately set a named buffer to avoid scratch label
  local main_tmp_buf = vim.api.nvim_create_buf(true, false) -- Listed, not scratch
  vim.api.nvim_buf_set_name(main_tmp_buf, "VSterm Terminal")
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = main_tmp_buf })
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), main_tmp_buf)

  -- Step 2: Create vertical split, terminal on left, list on right
  vim.cmd(string.format("rightbelow vertical %dsplit", config.options.list_width))
  term_list_win = vim.api.nvim_get_current_win()

  -- Prevent the terminal list window from auto-resizing
  vim.api.nvim_set_option_value("winfixwidth", true, { win = term_list_win })

  -- Prepare terminal list buffer if not exist
  if not term_list_buf or not vim.api.nvim_buf_is_valid(term_list_buf) then
    term_list_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(term_list_buf, "VSterm List")
  end

  -- Set list buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = term_list_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = term_list_buf })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = term_list_buf })
  vim.api.nvim_set_option_value("filetype", "vsterm", { buf = term_list_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = term_list_buf })

  -- Set buffer in terminal list window
  vim.api.nvim_win_set_buf(term_list_win, term_list_buf)

  -- Back to terminal window
  vim.cmd "wincmd h"
  main_win = vim.api.nvim_get_current_win()

  -- Prevent the terminal window from auto-resizing
  vim.api.nvim_set_option_value("winfixheight", true, { win = main_win })

  -- Apply window options to both windows
  apply_window_options(term_list_win)
  apply_window_options(main_win)

  -- Special handling for terminal list
  if vim.api.nvim_win_is_valid(term_list_win) then
    pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = term_list_win })
  end

  -- Setup keymaps for terminal list
  setup_terminal_list_keymaps()

  -- Navigate back to original window
  vim.api.nvim_set_current_win(current_win)
end

---Update the terminal list display
local function update_term_list()
  if not term_list_buf or not vim.api.nvim_buf_is_valid(term_list_buf) then
    return
  end

  local lines = {}
  local terminals = state.get_terminals()
  table.sort(terminals, function(a, b)
    return a.id < b.id
  end)

  local current_terminal_line = 1
  local current_terminal_id = state.get_current_terminal()

  -- Add terminals without header
  for i, term in ipairs(terminals) do
    local current = term.id == current_terminal_id
    if current then
      current_terminal_line = i
    end
    local num_prefix = i <= 9 and i .. ". " or "   "
    local prefix = (current and "▶ " or "  ") .. num_prefix
    table.insert(lines, prefix .. term.name)
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = term_list_buf })
  vim.api.nvim_buf_set_lines(term_list_buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = term_list_buf })

  -- Move cursor to the current terminal line in the terminal list window
  if term_list_win and vim.api.nvim_win_is_valid(term_list_win) then
    vim.api.nvim_win_set_cursor(term_list_win, { current_terminal_line, 0 })
  end

  setup_terminal_keymaps()
end

---Setup terminal UI
function M.setup()
  -- Nothing to do on initial setup
end

---Show the terminal UI
function M.show()
  if not state.is_visible() then
    -- Store the original window before creating layout
    original_win = vim.api.nvim_get_current_win()

    -- Create a terminal if none exists
    if #state.get_terminals() == 0 then
      local api = require "vsterm.api"
      api.create_terminal()
    end

    create_layout()
    state.set_visible(true)
  end

  -- Show current terminal and activate it
  local current_id = state.get_current_terminal()
  if current_id then
    local term = state.get_terminal(current_id)
    if term then
      ensure_terminal_buffer(term)
    end
  end

  update_term_list()
  M.focus_terminal()
end

---Hide the terminal UI
function M.hide()
  if main_win and vim.api.nvim_win_is_valid(main_win) then
    vim.api.nvim_win_close(main_win, true)
  end
  if term_list_win and vim.api.nvim_win_is_valid(term_list_win) then
    vim.api.nvim_win_close(term_list_win, true)
  end

  -- Restore focus to the original window
  if original_win and vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end

  main_win = nil
  term_list_win = nil
  original_win = nil

  -- Clean up help window
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_win_close(help_win, true)
  end
  help_win = nil

  state.set_visible(false)
end

---Get the main terminal window ID
---@return number|nil
function M.get_main_window()
  return main_win
end

---Get the original window
---@return number|nil
function M.get_original_window()
  return original_win
end

---Set the original window
---@param win_id number Window ID
function M.set_original_window(win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    original_win = win_id
  end
end

---Refresh the terminal UI
function M.refresh()
  if not state.is_visible() then
    return
  end

  local main_valid = main_win and vim.api.nvim_win_is_valid(main_win)
  local term_list_valid = term_list_win and vim.api.nvim_win_is_valid(term_list_win)

  if not main_valid or not term_list_valid then
    -- Clear invalid window refs
    if main_win and not vim.api.nvim_win_is_valid(main_win) then
      main_win = nil
    end
    if term_list_win and not vim.api.nvim_win_is_valid(term_list_win) then
      term_list_win = nil
    end

    -- Close windows showing terminal buffers or our terminal list buffer
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_is_valid(buf) then
          local bufname = vim.api.nvim_buf_get_name(buf)
          if
            bufname:match "vsterm%-list"
            or (bufname == "" and vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal")
          then
            pcall(vim.api.nvim_win_close, win, true)
          end
        end
      end
    end

    -- Delete term_list_buf buffer if valid
    if term_list_buf and vim.api.nvim_buf_is_valid(term_list_buf) then
      pcall(vim.api.nvim_buf_delete, term_list_buf, { force = true })
      term_list_buf = nil
    end

    -- Recreate the layout fresh, but preserve the original_win
    local saved_original_win = original_win
    create_layout()
    original_win = saved_original_win
    return
  end

  -- Update terminal buffer and apply window options
  local current_id = state.get_current_terminal()
  if current_id and main_win and vim.api.nvim_win_is_valid(main_win) then
    local term = state.get_terminal(current_id)
    if term then
      ensure_terminal_buffer(term)
    end
    vim.api.nvim_set_option_value("winfixheight", true, { win = main_win })
  end

  if term_list_win and vim.api.nvim_win_is_valid(term_list_win) then
    vim.api.nvim_set_option_value("winfixwidth", true, { win = term_list_win })
    apply_window_options(term_list_win)
  end

  if main_win and vim.api.nvim_win_is_valid(main_win) then
    apply_window_options(main_win)
  end

  update_term_list()
end

---Show help window with available keybindings
function M.show_help()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    -- Help window is already open, close it
    M.close_help()
    return
  end

  -- Create help buffer if it doesn't exist
  if not help_buf or not vim.api.nvim_buf_is_valid(help_buf) then
    help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(help_buf, "VSterm Help")
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = help_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = help_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = help_buf })
    vim.api.nvim_set_option_value("filetype", "help", { buf = help_buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = help_buf })
  end

  -- Help content
  local help_lines = {
    "Terminal Selection Help",
    "========================",
    "",
    "Navigation:",
    "  <Enter>    Select terminal",
    "  <Mouse>    Click to select terminal",
    "",
    "Terminal Management:",
    "  n          Create new terminal",
    "  d          Delete terminal",
    "  r          Rename terminal",
    "",
    "Other:",
    "  ?          Show/hide this help",
    "",
    "Press any key to close this help window.",
  }

  -- Set help content
  vim.api.nvim_set_option_value("modifiable", true, { buf = help_buf })
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = help_buf })

  -- Calculate window dimensions
  local width = 45
  local height = #help_lines + 2
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  help_win = vim.api.nvim_open_win(help_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " VSterm Help ",
    title_pos = "center",
  })

  -- Set help window options
  apply_window_options(help_win)
  vim.api.nvim_set_option_value("cursorline", true, { win = help_win })

  -- Set up keymaps to close help window
  local close_help_keys = { "q", "<Esc>", "?", "<CR>" }
  for _, key in ipairs(close_help_keys) do
    vim.keymap.set("n", key, function()
      M.close_help()
    end, { buffer = help_buf, silent = true })
  end

  -- Auto-close help window when user presses other keys
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = help_buf,
    once = true,
    callback = function()
      M.close_help()
    end,
  })
end

---Close help window
function M.close_help()
  if help_win and vim.api.nvim_win_is_valid(help_win) then
    vim.api.nvim_win_close(help_win, true)
  end
  help_win = nil

  -- Return focus to terminal list window
  if term_list_win and vim.api.nvim_win_is_valid(term_list_win) then
    vim.api.nvim_set_current_win(term_list_win)
  end
end

return M
