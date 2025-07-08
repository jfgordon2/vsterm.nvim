local config = require "vsterm.config"

local M = {}

---@class Terminal
---@field id number Unique terminal ID
---@field name string Display name
---@field bufnr number Neovim buffer number
---@field job_id number Terminal job ID
---@field win_id number|nil Window ID when visible
---@field cwd string|nil Working directory of the terminal

-- Internal state
local state = {
  terminals = {}, -- Map of terminal_id to Terminal
  current_id = nil,
  visible = false,
  next_id = 1,
}

---Initialize the terminal state
function M.init()
  state.terminals = {}
  state.current_id = nil
  state.visible = false
  state.next_id = 1
end

---Create a new terminal
---@param name string|nil Optional name for the terminal
---@return number terminal_id
function M.create_terminal(name)
  local id = state.next_id
  state.next_id = state.next_id + 1

  local term_name = name or string.format(config.options.default_name, id)

  state.terminals[id] = {
    id = id,
    name = term_name,
    bufnr = nil, -- Will be created when terminal is shown
    job_id = nil, -- Will be set when terminal is activated
    win_id = nil,
    cwd = vim.fn.getcwd(),
  }

  if not state.current_id then
    state.current_id = id
  end

  return id
end

---Get the current terminal ID
---@return number|nil
function M.get_current_terminal()
  return state.current_id
end

---Set the current terminal
---@param id number Terminal ID
function M.set_current_terminal(id)
  if state.terminals[id] then
    state.current_id = id
  end
end

---Get a terminal by ID
---@param id number Terminal ID
---@return Terminal|nil
function M.get_terminal(id)
  return state.terminals[id]
end

---Get all terminals
---@return Terminal[]
function M.get_terminals()
  local terminals = {}
  for _, term in pairs(state.terminals) do
    table.insert(terminals, term)
  end
  table.sort(terminals, function(a, b)
    return a.id < b.id
  end)
  return terminals
end

---Kill a terminal
---@param id number Terminal ID
function M.kill_terminal(id)
  local term = state.terminals[id]
  if not term then
    return
  end

  -- Stop the terminal job
  if term.job_id then
    vim.fn.jobstop(term.job_id)
  end

  -- Handle buffer deletion safely
  if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
    -- Simply try to delete the buffer with force
    -- The API layer will handle UI updates appropriately
    local ok, err = pcall(vim.api.nvim_buf_delete, term.bufnr, { force = true, unload = false })
    if not ok then
      -- If deletion fails, try to forcefully wipe it
      pcall(vim.cmd, "bwipeout! " .. term.bufnr)
    end
  end

  -- Remove from state
  state.terminals[id] = nil

  -- Switch to another terminal if this was the current one
  if state.current_id == id then
    local terminals = M.get_terminals()
    state.current_id = terminals[1] and terminals[1].id or nil
  end
end

---Rename a terminal
---@param id number Terminal ID
---@param new_name string New name
function M.rename_terminal(id, new_name)
  local term = state.terminals[id]
  if term then
    term.name = new_name
  end
end

---Check if terminal UI is visible
---@return boolean
function M.is_visible()
  return state.visible
end

---Set terminal UI visibility
---@param visible boolean
function M.set_visible(visible)
  state.visible = visible
end

---Set window ID for a terminal
---@param id number Terminal ID
---@param win_id number|nil Window ID
function M.set_window(id, win_id)
  local term = state.terminals[id]
  if term then
    term.win_id = win_id
  end
end

---Clean up terminal state without buffer deletion (for TermClose events)
---@param id number Terminal ID
function M.cleanup_terminal(id)
  local term = state.terminals[id]
  if not term then
    return
  end

  -- Remove from state
  state.terminals[id] = nil

  -- Switch to another terminal if this was the current one
  if state.current_id == id then
    local terminals = M.get_terminals()
    state.current_id = terminals[1] and terminals[1].id or nil
  end
end

---Find terminal by buffer number
---@param bufnr number Buffer number
---@return number|nil Terminal ID
function M.find_terminal_by_buffer(bufnr)
  for id, term in pairs(state.terminals) do
    if term.bufnr == bufnr then
      return id
    end
  end
  return nil
end

return M
