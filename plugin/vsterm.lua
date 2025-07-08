if vim.g.loaded_vsterm then
  return
end
vim.g.loaded_vsterm = true

-- Create user commands
local function create_user_commands()
  vim.api.nvim_create_user_command("VSTermToggle", function()
    local vsterm = require "vsterm"
    if not vsterm.toggle then
      vim.notify("VSterm not set up. Call require('vsterm').setup() first.", vim.log.levels.ERROR)
      return
    end
    vsterm.toggle()
  end, { desc = "Toggle terminal panel" })

  vim.api.nvim_create_user_command("VSTermNew", function()
    local vsterm = require "vsterm"
    if not vsterm.create_terminal then
      vim.notify("VSterm not set up. Call require('vsterm').setup() first.", vim.log.levels.ERROR)
      return
    end
    vsterm.create_terminal()
  end, { desc = "Create a new terminal" })

  vim.api.nvim_create_user_command("VSTermKill", function()
    local vsterm = require "vsterm"
    if not vsterm.kill_terminal then
      vim.notify("VSterm not set up. Call require('vsterm').setup() first.", vim.log.levels.ERROR)
      return
    end
    vsterm.kill_terminal()
  end, { desc = "Kill the current terminal" })

  vim.api.nvim_create_user_command("VSTermRename", function(opts)
    local vsterm = require "vsterm"
    if not vsterm.rename_terminal then
      vim.notify("VSterm not set up. Call require('vsterm').setup() first.", vim.log.levels.ERROR)
      return
    end
    if opts.args and opts.args ~= "" then
      vsterm.rename_terminal(opts.args)
    else
      vim.ui.input({ prompt = "New terminal name: " }, function(name)
        if name then
          vsterm.rename_terminal(name)
        end
      end)
    end
  end, {
    nargs = "?",
    desc = "Rename the current terminal",
  })
end

create_user_commands()
