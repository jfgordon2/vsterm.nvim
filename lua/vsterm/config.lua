local M = {}

---@class VSTermConfig
---@field height number Height of the terminal window (percentage of total height)
---@field default_name string Default name format for new terminals
---@field shell string|nil Shell to use (nil for default)
---@field direction "horizontal"|"vertical" Direction to split the terminal
---@field position "bottom"|"top"|"left"|"right" Position of the terminal window
---@field list_width number Width of the terminal list (in characters)
---@field auto_scroll boolean Automatically scroll to bottom on terminal output
---@field enable_mouse boolean Enable mouse support for terminal list
---@field number_prefix string|nil Key prefix for number-based terminal switching
---@field mappings table<string, string|function> Custom key mappings

-- Default configuration
M.options = {
  height = 0.3, -- 30% of window height
  default_name = "Terminal %d",
  shell = nil,
  direction = "horizontal",
  position = "bottom",
  list_width = 25,
  auto_scroll = true,
  enable_mouse = true,
  number_prefix = "<leader>v",
  mappings = {
    toggle = "<leader>vv",
    new = "<leader>vn",
    kill = "<leader>vk",
    rename = "<leader>vr",
  },
}

---Convert a key sequence string to its internal representation
---@param key string The key sequence (e.g. "<leader>t")
---@return string
function M.t(key)
  if vim.api.nvim_replace_termcodes then
    return vim.api.nvim_replace_termcodes(key, true, true, true)
  else
    return key
  end
end

---Setup the configuration
---@param opts VSTermConfig|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M

