local config = require "vsterm.config"
local state = require "vsterm.state"

local M = {}

-- Centralized window state
local windows = {
  main = nil,
  term_list = nil,
  help = nil,
  original = nil,
  last_height = nil, -- Store the last height of the terminal window
  last_list_width = nil, -- Store the last width of the terminal list window
}

local buffers = {
  term_list = nil,
  help = nil,
}

---Apply options for main terminal window
---@param win number Window ID
local function apply_main_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  pcall(vim.api.nvim_set_option_value, "number", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "relativenumber", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "signcolumn", "no", { win = win })
  pcall(vim.api.nvim_set_option_value, "foldcolumn", "0", { win = win })
  pcall(vim.api.nvim_set_option_value, "wrap", true, { win = win })
  pcall(vim.api.nvim_set_option_value, "statusline", "", { win = win, scope = "local" })
  pcall(vim.api.nvim_set_option_value, "winfixheight", true, { win = win })
end

---Apply options for terminal list window
---@param win number Window ID
local function apply_list_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  pcall(vim.api.nvim_set_option_value, "number", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "relativenumber", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "signcolumn", "no", { win = win })
  pcall(vim.api.nvim_set_option_value, "foldcolumn", "0", { win = win })
  pcall(vim.api.nvim_set_option_value, "wrap", true, { win = win })
  pcall(vim.api.nvim_set_option_value, "statusline", "", { win = win, scope = "local" })
  pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = win })
  pcall(vim.api.nvim_set_option_value, "winfixwidth", true, { win = win })
end

---Explicitly set the terminal list window width
local function set_term_list_width()
  if windows.term_list and vim.api.nvim_win_is_valid(windows.term_list) then
    local configured_width = config.options.list_width
    local width = configured_width
    if
      windows.last_list_width
      and windows.last_list_width >= math.floor(configured_width / 2)
      and windows.last_list_width <= configured_width * 2
    then
      width = windows.last_list_width
    end
    if width then
      vim.api.nvim_win_set_width(windows.term_list, width)
    end
  end
end

---Apply options for help window
---@param win number Window ID
local function apply_help_window_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  pcall(vim.api.nvim_set_option_value, "number", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "relativenumber", false, { win = win })
  pcall(vim.api.nvim_set_option_value, "signcolumn", "no", { win = win })
  pcall(vim.api.nvim_set_option_value, "foldcolumn", "0", { win = win })
  pcall(vim.api.nvim_set_option_value, "wrap", true, { win = win })
  pcall(vim.api.nvim_set_option_value, "statusline", "", { win = win, scope = "local" })
  pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = win })
end

---Check if all required windows are valid
---@return boolean|nil
local function are_windows_valid()
  return windows.main
    and vim.api.nvim_win_is_valid(windows.main)
    and windows.term_list
    and vim.api.nvim_win_is_valid(windows.term_list)
end

---Clean up invalid window references
local function cleanup_invalid_windows()
  for name, win in pairs(windows) do
    if win and not vim.api.nvim_win_is_valid(win) then
      windows[name] = nil
    end
  end
end

---Focus the main terminal window and start insert mode
---@param term_id number|nil Terminal ID to focus (current if nil)
function M.focus_terminal(term_id)
  if windows.main and vim.api.nvim_win_is_valid(windows.main) then
    vim.api.nvim_set_current_win(windows.main)

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

---Create or update terminal buffer in main window
---@param term Terminal Terminal object
local function ensure_terminal_buffer(term)
  if
    (not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr))
    and windows.main
    and vim.api.nvim_win_is_valid(windows.main)
  then
    -- Create a fresh buffer for the terminal
    local bufnr = vim.api.nvim_create_buf(false, true)

    -- Set the buffer in the main window first
    vim.api.nvim_win_set_buf(windows.main, bufnr)

    -- Switch to main window to start terminal
    local old_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(windows.main)

    -- Start terminal in the fresh buffer
    term.job_id = vim.fn.jobstart(config.options.shell or vim.o.shell, {
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify("Terminal exited with code " .. code, vim.log.levels.WARN)
        end
      end,
      term = true,
    })
    term.bufnr = bufnr

    -- Set buffer options
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = term.bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = term.bufnr })

    -- Apply window options
    apply_main_window_options(windows.main)

    -- Set up terminal-specific keymaps
    local api = require "vsterm.api"
    api.setup_terminal_keymaps()

    -- Go back to original window
    vim.api.nvim_set_current_win(old_win)
  else
    -- Set window to use the existing terminal buffer
    if windows.main then
      vim.api.nvim_win_set_buf(windows.main, term.bufnr)
      apply_main_window_options(windows.main)
    end
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

---Create terminal list buffer
local function create_terminal_list_buffer()
  if not buffers.term_list or not vim.api.nvim_buf_is_valid(buffers.term_list) then
    buffers.term_list = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffers.term_list, "VSterm List")

    -- Set list buffer options
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffers.term_list })
    vim.api.nvim_set_option_value("swapfile", false, { buf = buffers.term_list })
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buffers.term_list })
    vim.api.nvim_set_option_value("filetype", "vsterm", { buf = buffers.term_list })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffers.term_list })
  end
  return buffers.term_list
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
  if not buffers.term_list then
    return
  end

  -- Mouse support
  if config.options.enable_mouse then
    vim.keymap.set("n", "<LeftMouse>", function()
      local mouse = vim.fn.getmousepos()
      if mouse.winid == windows.term_list then
        local term_id = get_terminal_at_line(mouse.line)
        if term_id then
          state.set_current_terminal(term_id)
          M.refresh()
          M.focus_terminal(term_id)
        end
      end
    end, { buffer = buffers.term_list, silent = true })
  end

  -- Keyboard shortcuts
  vim.keymap.set("n", "<CR>", function()
    local term_id = get_terminal_at_line()
    if term_id then
      state.set_current_terminal(term_id)
      M.refresh()
      M.focus_terminal(term_id)
    end
  end, { buffer = buffers.term_list, silent = true })

  vim.keymap.set("n", "d", function()
    local term_id = get_terminal_at_line()
    if term_id then
      local api = require "vsterm.api"
      api.kill_terminal(term_id)
    end
  end, { buffer = buffers.term_list, silent = true })

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
  end, { buffer = buffers.term_list, silent = true })

  vim.keymap.set("n", "n", function()
    local api = require "vsterm.api"
    api.create_terminal()
  end, { buffer = buffers.term_list, silent = true })

  vim.keymap.set("n", "?", function()
    M.show_help()
  end, { buffer = buffers.term_list, silent = true })
end

---Create the main terminal window layout

local function create_layout()
  -- Save current window
  local current_win = vim.api.nvim_get_current_win()

  -- Calculate dimensions - use stored height if available, otherwise use config default
  local ui_height
  if windows.last_height then
    ui_height = windows.last_height
  else
    ui_height = math.floor(vim.o.lines * config.options.height)
  end

  -- Step 1: Create bottom horizontal split
  vim.cmd(string.format("botright %dsplit", ui_height))

  -- Set a named buffer
  local main_tmp_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(main_tmp_buf, "VSterm Terminal")
  vim.api.nvim_set_option_value("buftype", "nowrite", { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = main_tmp_buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = main_tmp_buf })
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), main_tmp_buf)

  -- Step 2: Use last_list_width for terminal list split if within bounds, else use configured width
  local configured_width = config.options.list_width
  local list_width = configured_width
  if
    windows.last_list_width
    and windows.last_list_width >= math.floor(configured_width / 2)
    and windows.last_list_width <= configured_width * 2
  then
    list_width = windows.last_list_width
  end
  vim.cmd(string.format("rightbelow vertical %dsplit", list_width))
  windows.term_list = vim.api.nvim_get_current_win()

  -- Create and set terminal list buffer
  local term_list_buf = create_terminal_list_buffer()
  if not term_list_buf or not vim.api.nvim_buf_is_valid(term_list_buf) then
    vim.notify("Failed to create terminal list buffer", vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_win_set_buf(windows.term_list, term_list_buf)

  -- Back to terminal window
  vim.cmd "wincmd h"
  windows.main = vim.api.nvim_get_current_win()

  -- Apply window options
  apply_main_window_options(windows.main)
  apply_list_window_options(windows.term_list)

  -- Setup keymaps for terminal list
  setup_terminal_list_keymaps()

  -- Navigate back to original window
  vim.api.nvim_set_current_win(current_win)
end

---Update the terminal list display
local function update_term_list()
  if not buffers.term_list or not vim.api.nvim_buf_is_valid(buffers.term_list) then
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

  vim.api.nvim_set_option_value("modifiable", true, { buf = buffers.term_list })
  vim.api.nvim_buf_set_lines(buffers.term_list, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buffers.term_list })

  -- Move cursor to the current terminal line in the terminal list window
  if windows.term_list and vim.api.nvim_win_is_valid(windows.term_list) then
    vim.api.nvim_win_set_cursor(windows.term_list, { current_terminal_line, 0 })
  end

  setup_terminal_keymaps()
end

---Show the terminal UI
function M.show()
  if not state.is_visible() then
    -- Store the original window before creating layout
    windows.original = vim.api.nvim_get_current_win()

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
  -- Store the current height before hiding
  if windows.main and vim.api.nvim_win_is_valid(windows.main) then
    windows.last_height = vim.api.nvim_win_get_height(windows.main)
  end

  -- Store the current list width before hiding
  if windows.term_list and vim.api.nvim_win_is_valid(windows.term_list) then
    local cur_width = vim.api.nvim_win_get_width(windows.term_list)
    if cur_width < math.floor(config.options.list_width / 2) or cur_width > config.options.list_width * 2 then
      windows.last_list_width = config.options.list_width
    else
      windows.last_list_width = cur_width
    end
  end

  if windows.main and vim.api.nvim_win_is_valid(windows.main) then
    vim.api.nvim_win_close(windows.main, true)
  end
  if windows.term_list and vim.api.nvim_win_is_valid(windows.term_list) then
    vim.api.nvim_win_close(windows.term_list, true)
  end

  -- Restore focus to the original window
  if windows.original and vim.api.nvim_win_is_valid(windows.original) then
    vim.api.nvim_set_current_win(windows.original)
  end

  -- Clear window references
  windows.main = nil
  windows.term_list = nil
  windows.original = nil

  -- Clean up help window
  if windows.help and vim.api.nvim_win_is_valid(windows.help) then
    vim.api.nvim_win_close(windows.help, true)
  end
  windows.help = nil

  state.set_visible(false)
end

---Get the main terminal window ID
---@return number|nil
function M.get_main_window()
  return windows.main
end

---Get the original window
---@return number|nil
function M.get_original_window()
  return windows.original
end

---Set the original window
---@param win_id number Window ID
function M.set_original_window(win_id)
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    windows.original = win_id
  end
end

---Reset the stored terminal dimensions to use config defaults
function M.reset_dimensions()
  windows.last_height = nil
  windows.last_list_width = nil
  if state.is_visible() then
    M.refresh()
  end
end

---Refresh the terminal UI
function M.refresh()
  if not state.is_visible() then
    return
  end

  if not are_windows_valid() then
    cleanup_invalid_windows()

    -- Store current height before cleanup if main window exists
    if windows.main and vim.api.nvim_win_is_valid(windows.main) then
      windows.last_height = vim.api.nvim_win_get_height(windows.main)
    end

    -- Store current list width before cleanup if term_list window exists
    if windows.term_list and vim.api.nvim_win_is_valid(windows.term_list) then
      windows.last_list_width = vim.api.nvim_win_get_width(windows.term_list)
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

    -- Delete term_list buffer if valid
    if buffers.term_list and vim.api.nvim_buf_is_valid(buffers.term_list) then
      pcall(vim.api.nvim_buf_delete, buffers.term_list, { force = true })
      buffers.term_list = nil
    end

    -- Recreate the layout fresh, but preserve the original_win
    local saved_original_win = windows.original
    create_layout()
    windows.original = saved_original_win
    set_term_list_width()
    return
  end

  -- Update terminal buffer
  local current_id = state.get_current_terminal()
  if current_id and windows.main and vim.api.nvim_win_is_valid(windows.main) then
    local term = state.get_terminal(current_id)
    if term then
      ensure_terminal_buffer(term)
    end
  end

  update_term_list()
  set_term_list_width()
end

---Show help window with available keybindings
function M.show_help()
  if windows.help and vim.api.nvim_win_is_valid(windows.help) then
    -- Help window is already open, close it
    M.close_help()
    return
  end

  -- Create help buffer if it doesn't exist
  if not buffers.help or not vim.api.nvim_buf_is_valid(buffers.help) then
    buffers.help = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buffers.help, "VSterm Help")
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffers.help })
    vim.api.nvim_set_option_value("swapfile", false, { buf = buffers.help })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buffers.help })
    vim.api.nvim_set_option_value("filetype", "help", { buf = buffers.help })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buffers.help })
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
  vim.api.nvim_set_option_value("modifiable", true, { buf = buffers.help })
  vim.api.nvim_buf_set_lines(buffers.help, 0, -1, false, help_lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buffers.help })

  -- Calculate window dimensions
  local width = 45
  local height = #help_lines + 2
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  windows.help = vim.api.nvim_open_win(buffers.help, true, {
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
  apply_help_window_options(windows.help)

  -- Set up keymaps to close help window
  local close_help_keys = { "q", "<Esc>", "?", "<CR>" }
  for _, key in ipairs(close_help_keys) do
    vim.keymap.set("n", key, function()
      M.close_help()
    end, { buffer = buffers.help, silent = true })
  end

  -- Auto-close help window when user presses other keys
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buffers.help,
    once = true,
    callback = function()
      M.close_help()
    end,
  })
end

---Close help window
function M.close_help()
  if windows.help and vim.api.nvim_win_is_valid(windows.help) then
    vim.api.nvim_win_close(windows.help, true)
  end
  windows.help = nil

  -- Return focus to terminal list window
  if windows.term_list and vim.api.nvim_win_is_valid(windows.term_list) then
    vim.api.nvim_set_current_win(windows.term_list)
  end
end

return M
