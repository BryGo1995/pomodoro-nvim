local M = {}
local uv = vim.uv or vim.loop

local defaults = {
  work_minutes        = 25,
  break_minutes       = 5,
  long_break_minutes  = 15,
  long_break_interval = 4,
}

-- Internal state
local state = {
  phase             = "idle",   -- "idle" | "work" | "break" | "long_break"
  running           = false,
  remaining_seconds = 0,
  timer_handle      = nil,
  _generation       = 0,        -- incremented on each new phase; stale ticks are discarded
  set_count         = 0,        -- pomodoros completed in current set
  daily_count       = 0,        -- total pomodoros today
  config            = vim.deepcopy(defaults),
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
  if state.timer_handle then
    state.timer_handle:stop()
    state.timer_handle:close()
    state.timer_handle = nil
  end
  state.phase = "idle"
  state.running = false
  state.remaining_seconds = 0
  state._generation = 0
  state.set_count = 0
  state.daily_count = 0
end

-- Exposed for testing only: merge partial state
-- Only accepts known state keys to catch typos at test time
function M._set_state(partial)
  local valid_keys = {
    phase = true, running = true, remaining_seconds = true,
    timer_handle = true, config = true, set_count = true, daily_count = true,
  }
  for k, v in pairs(partial) do
    assert(valid_keys[k], "Unknown state key: " .. tostring(k))
    state[k] = v
  end
end

function M.statusline()
  if not state.running then return "" end
  local icon = (state.phase == "break" or state.phase == "long_break") and "☕" or "🍅"
  return icon .. " " .. M._format_time(state.remaining_seconds)
end

-- Exposed for testing only
function M._get_config()
  return state.config
end

-- Exposed for testing: accepts optional path override
-- Without a path argument, loads from ~/.config/nvim/pomodoro.lua
function M._load_config(path)
  path = path or vim.fn.expand("~/.config/nvim/pomodoro.lua")
  assert(type(path) == "string", "pomodoro: config path must be a string, got " .. type(path))
  local ok, user_config = pcall(dofile, path)
  if ok and type(user_config) == "table" then
    state.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), user_config)
  else
    state.config = vim.deepcopy(defaults)
  end
end

-- Exposed for testing only
function M._get_state()
  return state
end

-- Stop and close the libuv timer handle
local function stop_handle()
  if state.timer_handle then
    state.timer_handle:stop()
    state.timer_handle:close()
    state.timer_handle = nil
  end
end

-- Tick handler — called every second by the timer
-- Exposed for testing only
-- gen: the generation this tick belongs to; stale ticks from old timers are discarded
function M._tick(gen)
  if gen ~= state._generation then return end  -- stale tick from a stopped phase
  if state.remaining_seconds > 0 then
    state.remaining_seconds = state.remaining_seconds - 1
  else
    stop_handle()
    if state.phase == "work" then
      vim.notify("Time's up! Take a break.", vim.log.levels.INFO, { title = "Pomodoro" })
      M._start_phase("break")
    else
      state.running = false
      state.phase = "idle"
      vim.notify("Break over! Ready to focus?", vim.log.levels.INFO, { title = "Pomodoro" })
    end
  end
end

-- Start a timer phase. phase = "work" | "break" | "long_break"
-- Exposed for testing (tests call this directly instead of start() to avoid
-- spinning up a real vim.loop timer)
function M._start_phase(phase)
  assert(phase == "work" or phase == "break" or phase == "long_break",
    "pomodoro: invalid phase: " .. tostring(phase))
  stop_handle()
  state._generation = state._generation + 1
  local gen = state._generation
  state.phase = phase
  local duration_map = {
    work       = state.config.work_minutes,
    ["break"]  = state.config.break_minutes,
    long_break = state.config.long_break_minutes,
  }
  state.remaining_seconds = (duration_map[phase] or state.config.work_minutes) * 60
  state.running = true

  state.timer_handle = uv.new_timer()
  state.timer_handle:start(1000, 1000, vim.schedule_wrap(function()
    M._tick(gen)
  end))
end

function M.start()
  if state.running then return end
  M._start_phase("work")
  vim.notify(
    "Pomodoro started! Focus for " .. state.config.work_minutes .. " minutes.",
    vim.log.levels.INFO,
    { title = "Pomodoro" }
  )
end

function M.stop()
  stop_handle()
  state.running = false
  state.phase = "idle"
  state.remaining_seconds = 0
end

function M.skip()
  if not state.running then return end
  stop_handle()
  if state.phase == "work" then
    vim.notify("Work skipped. Take a break.", vim.log.levels.INFO, { title = "Pomodoro" })
    M._start_phase("break")
  else
    state.running = false
    state.phase = "idle"
    state.remaining_seconds = 0
    vim.notify("Break skipped. Ready to focus?", vim.log.levels.INFO, { title = "Pomodoro" })
  end
end

function M.toggle()
  if state.running then
    M.stop()
  else
    M.start()
  end
end

function M.setup(opts)
  M._load_config()
  if opts then
    state.config = vim.tbl_deep_extend("force", state.config, opts)
  end

  vim.api.nvim_create_user_command("PomodoroStart",  function() M.start()  end, { force = true })
  vim.api.nvim_create_user_command("PomodoroStop",   function() M.stop()   end, { force = true })
  vim.api.nvim_create_user_command("PomodoroSkip",   function() M.skip()   end, { force = true })
  vim.api.nvim_create_user_command("PomodoroToggle", function() M.toggle() end, { force = true })
end

return M
