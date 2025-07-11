local config = require "vsterm.config"
local state = require "vsterm.state"
local ui = require "vsterm.ui"
local utils = require "vsterm.utils"

local M = {}

---Create a new terminal
---@param name string|nil Optional name for the terminal
---@return number terminal_id
function M.create_terminal(name)
  -- Ensure setup has been called
  if not state.get_current_terminal() and #state.get_terminals() == 0 then
    state.init()
  end

  local id = state.create_terminal(name)

  -- If the terminal panel is visible, switch to and focus the new terminal
  if state.is_visible() then
    state.set_current_terminal(id)
    ui.refresh()
    ui.focus_terminal(id)
  else
    -- If panel is not visible, just refresh (no focus change)
    ui.refresh()
  end

  return id
end

---Toggle the terminal window
function M.toggle()
  if state.is_visible() then
    ui.hide()
  else
    -- Store current window as original before showing terminal
    local current_win = vim.api.nvim_get_current_win()
    local ui_module = require "vsterm.ui"
    -- Update original_win if we're switching from a non-terminal window
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = vim.api.nvim_win_get_buf(current_win) })
    if buftype ~= "terminal" and buftype ~= "nofile" then
      ui_module.set_original_window(current_win)
    end
    ui.show()
  end
end

---Kill the current or specified terminal
---@param term_id number|nil Terminal ID to kill (current if nil)
function M.kill_terminal(term_id)
  local id_to_kill = term_id or state.get_current_terminal()
  if not id_to_kill then
    return
  end

  state.kill_terminal(id_to_kill)

  -- If no terminals remain, hide the UI
  if #state.get_terminals() == 0 then
    if state.is_visible() then
      ui.hide()
    end
  else
    -- Refresh UI to show the new current terminal
    ui.refresh()

    -- Focus the main terminal window and start insert mode
    if state.is_visible() then
      ui.focus_terminal()
    end
  end
end

---Rename the current or specified terminal
---@param new_name string New name for the terminal
---@param term_id number|nil Terminal ID to rename (current if nil)
function M.rename_terminal(new_name, term_id)
  term_id = term_id or state.get_current_terminal()
  if not term_id then
    vim.notify("No terminal to rename", vim.log.levels.WARN)
    return
  end
  state.rename_terminal(term_id, new_name)
  ui.refresh()
end

---Switch to a specific terminal
---@param term_id number Terminal ID to switch to
function M.switch_terminal(term_id)
  state.set_current_terminal(term_id)
  ui.refresh()
  if state.is_visible() then
    ui.focus_terminal(term_id)
  end
end

---Get a list of all terminals
---@return Terminal[]
function M.get_terminals()
  return state.get_terminals()
end

---Get the current terminal
---@return Terminal|nil
function M.get_current_terminal()
  local id = state.get_current_terminal()
  return id and state.get_terminal(id) or nil
end

---Reset terminal window dimensions to config defaults
function M.reset_dimensions()
  ui.reset_dimensions()
end

---Setup terminal manager keymaps
local function setup_keymaps()
  local function set_keymap(mode, lhs, rhs, desc)
    if type(lhs) == "string" and lhs ~= "" then
      vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
    end
  end

  local maps = config.options.mappings
  if maps then
    set_keymap("n", maps.toggle, M.toggle, "Toggle terminal window")
    set_keymap("n", maps.new, M.create_terminal, "Create new terminal")
    set_keymap("n", maps.kill, M.kill_terminal, "Kill current terminal")
    set_keymap("n", maps.rename, function()
      vim.ui.input({ prompt = "New terminal name: " }, function(name)
        if name then
          M.rename_terminal(name)
        end
      end)
    end, "Rename current terminal")
  end
end

-- Function for opening file in original window
function M.open_file_in_original_win()
  local original_win = ui.get_original_window()
  local filename = vim.fn.expand "<cfile>"

  if filename == "" then
    return
  end

  if not utils.is_valid_file(filename) then
    vim.notify("File does not exist: " .. filename, vim.log.levels.ERROR)
    return
  end

  if not original_win or not vim.api.nvim_win_is_valid(original_win) then
    -- Find the first non-terminal window as fallback
    original_win = utils.get_first_non_terminal_window()
  end

  if original_win and vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
    vim.cmd("edit " .. vim.fn.fnameescape(filename))
  end
end

---Open to pytest function or line:col in original window
function M.gF_to_original_win()
  local original_win = ui.get_original_window()
  local filename, pytest_parts = utils.extract_pytest_path_from_line()

  if filename == nil then
    return
  end

  if not utils.is_valid_file(filename) then
    vim.notify("File does not exist: " .. filename, vim.log.levels.ERROR)
    return
  end

  if not original_win or not vim.api.nvim_win_is_valid(original_win) then
    -- Find the first non-terminal window as fallback
    original_win = utils.get_first_non_terminal_window()
  end

  if original_win and vim.api.nvim_win_is_valid(original_win) then
    if pytest_parts and #pytest_parts > 0 then
      -- If pytest parts are provided, open the file at the specified function
      utils.open_file_at_window_and_pytest_function(original_win, filename, pytest_parts)
    else
      local _, line_num, col_num = utils.extract_line_and_column_from_line()
      utils.open_file_at_window(original_win, filename, line_num, col_num)
    end
  end
end

---Set keymaps when a terminal buffer is active
function M.setup_terminal_keymaps()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Only set keymaps if this is actually a terminal buffer
  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "terminal" then
    -- Set keymaps for normal mode in terminal buffer (when you press <C-\><C-n>)
    vim.keymap.set(
      "n",
      "gf",
      "<cmd>lua require('vsterm.api').open_file_in_original_win()<CR>",
      { buffer = bufnr, noremap = true, silent = true, desc = "Open file in original window" }
    )
    vim.keymap.set(
      "n",
      "gF",
      "<cmd>lua require('vsterm.api').gF_to_original_win()<CR>",
      { buffer = bufnr, noremap = true, silent = true, desc = "Open file with line in original window" }
    )

    -- Also set keymaps for terminal mode
    vim.keymap.set(
      "t",
      "gf",
      "<C-\\><C-n>:lua require('vsterm.api').open_file_in_original_win()<CR>",
      { buffer = bufnr, noremap = true, silent = true, desc = "Open file in original window" }
    )
    vim.keymap.set(
      "t",
      "gF",
      "<C-\\><C-n>:lua require('vsterm.api').gF_to_original_win()<CR>",
      { buffer = bufnr, noremap = true, silent = true, desc = "Open file with line in original window" }
    )
  end
end

---Initialize the terminal manager
function M.setup()
  state.init()
  setup_keymaps()
  M.setup_terminal_keymaps()

  -- Set up autocommands for terminal management
  vim.api.nvim_create_autocmd("TermClose", {
    pattern = "*",
    callback = function(ev)
      -- Check if this is one of our terminals and handle cleanup
      local term_id = state.find_terminal_by_buffer(ev.buf)
      if term_id then
        -- Terminal closed naturally, just clean up state
        -- Don't call kill_terminal to avoid double deletion
        state.cleanup_terminal(term_id)

        -- Refresh UI
        ui.refresh()
      end
    end,
  })

  -- Set up autocommand to apply terminal keymaps when terminal buffers are opened
  vim.api.nvim_create_autocmd("TermOpen", {
    pattern = "*",
    callback = function(ev)
      -- Check if this is one of our terminals
      local term_id = state.find_terminal_by_buffer(ev.buf)
      if term_id then
        -- Set up the terminal-specific keymaps
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            local current_buf = vim.api.nvim_get_current_buf()
            if current_buf == ev.buf then
              vim.opt_local.laststatus = 0 -- Hide status line in terminal buffers
              M.setup_terminal_keymaps()
            end
          end
        end)
      end
    end,
  })

  -- Set up autocommand to apply terminal keymaps when entering terminal buffers
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function(ev)
      -- Check if this is one of our terminals
      local term_id = state.find_terminal_by_buffer(ev.buf)
      if term_id then
        -- Set up the terminal-specific keymaps
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(ev.buf) then
            vim.opt_local.laststatus = 0 -- Hide status line in terminal buffers
            M.setup_terminal_keymaps()
          end
        end)
      end
    end,
  })
end

return M
