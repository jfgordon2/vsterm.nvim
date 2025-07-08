# VSterm.nvim

A Neovim plugin that provides a VSCode-like terminal management experience with a terminal panel at the bottom of the screen and a terminal list for easy switching.

## Features

- **Toggle-able terminal panel** - Appears at the bottom of the screen when toggled
- **Multiple terminal instances** - Create and manage multiple terminals
- **Terminal list sidebar** - Shows all terminals with easy switching
- **Mouse support** - Click on terminals in the list to switch
- **Dynamic keybindings** - Number-based shortcuts (e.g., `<leader>v1`, `<leader>v2`)
- **Terminal management** - Create, rename, and delete terminals
- **Configurable** - Customize height, width, keybindings, and appearance

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "jfgordon2/vsterm.nvim",
  config = function()
    require("vsterm").setup({
      -- Optional configuration
      height = 0.3, -- 30% of window height
      default_name = "Terminal %d",
      shell = vim.o.shell,
      direction = "horizontal",
      position = "bottom",
      list_width = 30,
    })
  end,
}
```

## Usage

### Commands

- `:VSTermToggle` - Toggle terminal panel
- `:VSTermNew` - Create a new terminal
- `:VSTermKill` - Kill the current terminal
- `:VSTermRename <name>` - Rename the current terminal

### Default Keymaps

- `<leader>vv` - Toggle terminal panel
- `<leader>vn` - New terminal
- `<leader>vk` - Kill current terminal
- `<leader>vr` - Rename current terminal

## Configuration

```lua
require("vsterm").setup({
  -- Height of the terminal window (percentage of total height)
  height = 0.3,
  
  -- Default name format for new terminals
  default_name = "Terminal %d",
  
  -- Shell to use (nil for default)
  shell = nil,
  
  -- Direction to split the terminal
  direction = "horizontal",
  
  -- Position of the terminal window
  position = "bottom",
  
  -- Width of the terminal list (in characters)
  list_width = 25,
  
  -- Automatically scroll to bottom on terminal output
  auto_scroll = true,
  
  -- Enable mouse support for terminal list
  enable_mouse = true,
  
  -- Key prefix for number-based terminal switching
  -- Set to nil to disable number shortcuts
  number_prefix = "<leader>v",
  
  -- Custom key mappings
  mappings = {
    toggle = "<leader>vv",
    new = "<leader>vn",
    kill = "<leader>vk",
    rename = "<leader>vr",
  },
})
```

### Dynamic Terminal Switching

When `number_prefix` is set (e.g., to `"<leader>v"`), the plugin will automatically create keymaps for switching between terminals:

- `<leader>v1` - Switch to first terminal
- `<leader>v2` - Switch to second terminal
- `<leader>v3` - Switch to third terminal
- etc...

These keymaps are dynamically updated as terminals are created and destroyed, always matching the order shown in the terminal list.

### Mouse Support

When `enable_mouse` is set to `true`, you can:

- Click on a terminal in the list to switch to it
- The active terminal is marked with a "▶" indicator

### Terminal List Keybindings

When the terminal list window is focused, you can use:

- `<Enter>` - Switch to the terminal under cursor
- `d` - Delete the terminal under cursor
- `r` - Rename the terminal under cursor  
- `n` - Create a new terminal
- `?` - Show help for terminal list commands
- Mouse click - Switch to clicked terminal

## License

MIT

