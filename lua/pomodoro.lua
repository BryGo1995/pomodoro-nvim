local M = {}

-- Internal state
local state = {
  running = false,
  is_break = false,
  remaining_seconds = 0,
  timer_handle = nil,
  config = {
    work_minutes = 25,
    break_minutes = 5,
  },
}

-- Exposed for testing only
function M._format_time(seconds)
  local m = math.floor(seconds / 60)
  local s = seconds % 60
  return string.format("%02d:%02d", m, s)
end

-- Exposed for testing only: reset runtime state to defaults
-- Deliberately does NOT reset config; use _set_state({ config = {...} }) to override config in tests
function M._reset_state()
  state.running = false
  state.is_break = false
  state.remaining_seconds = 0
  state.timer_handle = nil
end

-- Exposed for testing only: merge partial state
-- Only accepts known state keys to catch typos at test time
function M._set_state(partial)
  local valid_keys = { running = true, is_break = true, remaining_seconds = true, timer_handle = true, config = true }
  for k, v in pairs(partial) do
    assert(valid_keys[k], "Unknown state key: " .. tostring(k))
    state[k] = v
  end
end

function M.statusline()
  if not state.running then return "" end
  local icon = state.is_break and "☕" or "🍅"
  return icon .. " " .. M._format_time(state.remaining_seconds)
end

local defaults = {
  work_minutes = 25,
  break_minutes = 5,
}

-- Exposed for testing only
function M._get_config()
  return state.config
end

-- Exposed for testing: accepts optional path override
-- Without a path argument, loads from ~/.config/nvim/pomodoro.lua
function M._load_config(path)
  path = path or vim.fn.expand("~/.config/nvim/pomodoro.lua")
  local ok, user_config = pcall(dofile, path)
  if ok and type(user_config) == "table" then
    state.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_config)
  else
    state.config = vim.deepcopy(defaults)
  end
end

return M
