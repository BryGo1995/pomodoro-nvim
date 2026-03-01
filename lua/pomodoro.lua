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

-- Exposed for testing only: reset state to defaults
function M._reset_state()
  state.running = false
  state.is_break = false
  state.remaining_seconds = 0
  state.timer_handle = nil
end

-- Exposed for testing only: merge partial state
function M._set_state(partial)
  for k, v in pairs(partial) do
    state[k] = v
  end
end

function M.statusline()
  if not state.running then return "" end
  local icon = state.is_break and "☕" or "🍅"
  return icon .. " " .. M._format_time(state.remaining_seconds)
end

return M
