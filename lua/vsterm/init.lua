local M = {}

---Setup the plugin
---@param opts table|nil Configuration options
function M.setup(opts)
  -- Set up configuration first
  local config = require "vsterm.config"
  config.setup(opts)

  -- Load and initialize API
  local api = require "vsterm.api"
  api.setup()

  -- Re-export API functions
  M.create_terminal = api.create_terminal
  M.toggle = api.toggle
  M.kill_terminal = api.kill_terminal
  M.rename_terminal = api.rename_terminal
  M.switch_terminal = api.switch_terminal
  M.get_terminals = api.get_terminals
  M.get_current_terminal = api.get_current_terminal
end

return M
