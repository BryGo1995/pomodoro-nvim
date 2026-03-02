# pomodoro.nvim

A lightweight, zero-dependency Pomodoro timer for NeoVim.

- Live countdown in your statusline
- Popup notifications at the start and end of each phase
- Configurable work/break durations
- Single Lua file, no external dependencies

## Requirements

- NeoVim 0.7+

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "BryGo1995/pomodoro-nvim",
  config = function()
    require("pomodoro").setup()
  end,
}
```

**Local path install** (for development or testing before pushing):

```lua
{
  dir = "/path/to/pomodoro.nvim",
  config = function()
    require("pomodoro").setup()
  end,
}
```

## Configuration

Create `~/.config/nvim/pomodoro.lua`:

```lua
return {
  work_minutes        = 25,  -- default: 25
  break_minutes       = 5,   -- default: 5
  long_break_minutes  = 15,  -- default: 15
  long_break_interval = 4,   -- default: 4 (long break after every N sessions)
}
```

The config file is optional — if it does not exist, defaults are used silently.

Or pass options directly to `setup()` (takes precedence over config file):

```lua
require("pomodoro").setup({
  work_minutes = 50,
  break_minutes = 10,
})
```

## Statusline Integration

### lualine

```lua
require("lualine").setup({
  sections = {
    lualine_x = { require("pomodoro").statusline },
  },
})
```

The statusline format:

| Phase | Example | Description |
|---|---|---|
| Work | `🍅×7 ●●○○ 24:30` | daily count, set progress dots, countdown |
| Short break | `☕×7 ●●○○ 04:30` | |
| Long break | `🌙×7 14:30` | no dots — set just reset |
| Stopped | _(empty)_ | |

The daily count (`×7`) persists across NeoVim sessions and resets at midnight.

## Commands

| Command | Description |
|---|---|
| `:PomodoroStart` | Start a new work session |
| `:PomodoroStop` | Stop and reset the timer |
| `:PomodoroSkip` | Skip to the next phase |
| `:PomodoroToggle` | Start if stopped, stop if running |

## Suggested Keymaps

Add to your NeoVim config (optional):

```lua
vim.keymap.set("n", "<leader>ps", "<cmd>PomodoroStart<cr>",  { desc = "Pomodoro start" })
vim.keymap.set("n", "<leader>px", "<cmd>PomodoroStop<cr>",   { desc = "Pomodoro stop" })
vim.keymap.set("n", "<leader>pn", "<cmd>PomodoroSkip<cr>",   { desc = "Pomodoro skip" })
vim.keymap.set("n", "<leader>pt", "<cmd>PomodoroToggle<cr>", { desc = "Pomodoro toggle" })
```

## License

MIT
