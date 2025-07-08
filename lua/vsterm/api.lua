local config = require "vsterm.config"
local state = require "vsterm.state"
local ui = require "vsterm.ui"

local api = {}

---Create a new terminal
---@param name string|nil Optional name for the terminal
---@return number terminal_id
function api.create_terminal(name)
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
function api.toggle()
  if state.is_visible() then
    ui.hide()
  else
    ui.show()
  end
end

---Kill the current or specified terminal
---@param term_id number|nil Terminal ID to kill (current if nil)
function api.kill_terminal(term_id)
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
function api.rename_terminal(new_name, term_id)
  state.rename_terminal(term_id or state.get_current_terminal(), new_name)
  ui.refresh()
end

---Switch to a specific terminal
---@param term_id number Terminal ID to switch to
function api.switch_terminal(term_id)
  state.set_current_terminal(term_id)
  ui.refresh()
  if state.is_visible() then
    ui.focus_terminal(term_id)
  end
end

---Get a list of all terminals
---@return Terminal[]
function api.get_terminals()
  return state.get_terminals()
end

---Get the current terminal
---@return Terminal|nil
function api.get_current_terminal()
  local id = state.get_current_terminal()
  return id and state.get_terminal(id) or nil
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
    set_keymap("n", maps.toggle, api.toggle, "Toggle terminal window")
    set_keymap("n", maps.new, api.create_terminal, "Create new terminal")
    set_keymap("n", maps.kill, api.kill_terminal, "Kill current terminal")
    set_keymap("n", maps.rename, function()
      vim.ui.input({ prompt = "New terminal name: " }, function(name)
        if name then
          api.rename_terminal(name)
        end
      end)
    end, "Rename current terminal")
  end
end

---Initialize the terminal manager
function api.setup()
  state.init()
  ui.setup()
  setup_keymaps()

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
end

return api
