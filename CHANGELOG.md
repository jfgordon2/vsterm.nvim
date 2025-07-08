# VSterm.nvim Changelog

## Usage

### Quick Setup

```lua
require("vsterm").setup({
  height = 0.3,              -- 30% of screen height
  default_name = "Terminal %d",
  list_width = 30,           -- Terminal list width
  number_prefix = "<leader>v", -- For <leader>v1, <leader>v2, etc.
  mappings = {
    toggle = "<leader>vv",    -- Toggle terminal panel
    new = "<leader>vn",      -- Create new terminal
    kill = "<leader>vk",     -- Kill current terminal
    rename = "<leader>vr",   -- Rename current terminal
  },
})
```

### Commands

- `:VSTermToggle` - Toggle terminal panel
- `:VSTermNew` - Create new terminal
- `:VSTermKill` - Kill current terminal
- `:VSTermRename [name]` - Rename current terminal

### Expected Layout

```txt
┌─────────────────────────────────────────┐
│              Main Editor                │
│                                         │
├─────────────────────────┬───────────────┤
│      Terminal 1         │ Terminal List │
│      (Active)           │ ▶ 1. Term 1   │
│                         │   2. Term 2   │
│      $ ls               │   3. Term 3   │
│      file1.txt          │               │
│      file2.txt          │               │
│      $                  │               │
└─────────────────────────┴───────────────┘
```
