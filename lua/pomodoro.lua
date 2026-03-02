local M = {}
local uv = vim.uv or vim.loop

local defaults = {
  work_minutes        = 25,
  break_minutes       = 5,
  long_break_minutes  = 15,
  long_break_interval = 4,
  blink_interval_ms   = 1000,
  notify_at           = { 0.5, 0.75, 60 },
}

-- Internal state
local state = {
  phase             = "idle",   -- "idle" | "work" | "break" | "long_break"
  running           = false,
  remaining_seconds = 0,
  timer_handle      = nil,
  _generation       = 0,        -- incremented on each new phase; stale ticks are discarded
  set_count         = 0,        -- pomodoros completed in current set

  -- Per-activity daily counts (replaces daily_count)
  daily_pomodoros   = 0,
  daily_breaks      = 0,
  daily_long_breaks = 0,

  -- Notification tracking (computed on each _start_phase)
  total_seconds     = 0,
  notify_targets    = {},       -- sorted descending list of remaining_seconds thresholds
  notify_idx        = 1,        -- index of next threshold to fire

  -- Blink
  blink_visible     = true,
  blink_handle      = nil,

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
  if state.blink_handle then
    pcall(function()
      state.blink_handle:stop()
      state.blink_handle:close()
    end)
    state.blink_handle = nil
  end
  state.phase             = "idle"
  state.running           = false
  state.remaining_seconds = 0
  state._generation       = 0
  state.set_count         = 0
  state.daily_pomodoros   = 0
  state.daily_breaks      = 0
  state.daily_long_breaks = 0
  state.total_seconds     = 0
  state.notify_targets    = {}
  state.notify_idx        = 1
  state.blink_visible     = true
end

-- Path to the daily count persistence file
local function daily_file_path()
  return vim.fn.stdpath("data") .. "/pomodoro-daily.json"
end

-- Exposed for testing: accepts optional path override
function M._save_daily_counts(path)
  path = path or daily_file_path()
  local data = vim.fn.json_encode({
    date        = os.date("%Y-%m-%d"),
    pomodoros   = state.daily_pomodoros,
    breaks      = state.daily_breaks,
    long_breaks = state.daily_long_breaks,
  })
  local ok = pcall(vim.fn.writefile, { data }, path)
  if not ok then
    vim.notify("pomodoro: could not save daily counts", vim.log.levels.WARN, { title = "Pomodoro" })
  end
end

-- Exposed for testing: accepts optional path override
-- Supports old schema { date, count } and new schema { date, pomodoros, breaks, long_breaks }
function M._load_daily_counts(path)
  path = path or daily_file_path()
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or #lines == 0 then return end
  local ok2, data = pcall(vim.fn.json_decode, lines[1])
  if not ok2 or type(data) ~= "table" then return end
  if data.date ~= os.date("%Y-%m-%d") then return end
  if type(data.pomodoros) == "number" then
    -- New schema
    state.daily_pomodoros   = data.pomodoros
    state.daily_breaks      = type(data.breaks) == "number"      and data.breaks      or 0
    state.daily_long_breaks = type(data.long_breaks) == "number" and data.long_breaks or 0
  elseif type(data.count) == "number" then
    -- Old schema: map count → pomodoros, default others to 0
    state.daily_pomodoros   = data.count
    state.daily_breaks      = 0
    state.daily_long_breaks = 0
  end
end

-- Exposed for testing only: merge partial state
-- Only accepts known state keys to catch typos at test time
function M._set_state(partial)
  local valid_keys = {
    phase = true, running = true, remaining_seconds = true,
    timer_handle = true, config = true, set_count = true,
    daily_pomodoros = true, daily_breaks = true, daily_long_breaks = true,
    total_seconds = true, notify_targets = true, notify_idx = true,
    blink_visible = true, blink_handle = true,
  }
  for k, v in pairs(partial) do
    assert(valid_keys[k], "Unknown state key: " .. tostring(k))
    state[k] = v
  end
end

-- Build dot progress string: ● for completed, ○ for remaining
local function make_dots(count, interval)
  local dots = ""
  for i = 1, interval do
    dots = dots .. (i <= count and "●" or "○")
  end
  return dots
end

function M.statusline()
  if not state.running then return "" end
  local show_time = state.blink_visible or state.remaining_seconds > 60
  local time_str  = show_time and (" " .. M._format_time(state.remaining_seconds)) or ""
  if state.phase == "work" then
    local count = "×" .. state.daily_pomodoros
    local dots  = make_dots(state.set_count, state.config.long_break_interval)
    return "🍅" .. count .. " " .. dots .. time_str
  elseif state.phase == "break" then
    local count = "×" .. state.daily_breaks
    local dots  = make_dots(state.set_count, state.config.long_break_interval)
    return "☕" .. count .. " " .. dots .. time_str
  elseif state.phase == "long_break" then
    local count = "×" .. state.daily_long_breaks
    return "🌙" .. count .. time_str
  end
  return ""
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

-- Stop and close the main libuv timer handle
local function stop_handle()
  if state.timer_handle then
    state.timer_handle:stop()
    state.timer_handle:close()
    state.timer_handle = nil
  end
end

-- Stop and close the blink libuv timer handle; reset blink_visible
local function stop_blink_handle()
  if state.blink_handle then
    state.blink_handle:stop()
    state.blink_handle:close()
    state.blink_handle = nil
  end
  state.blink_visible = true
end

local phase_labels = {
  work       = "Pomodoro",
  ["break"]  = "Break",
  long_break = "Long break",
}

-- Tick handler — called every second by the timer
-- Exposed for testing only
-- gen: the generation this tick belongs to; stale ticks from old timers are discarded
function M._tick(gen)
  if gen ~= state._generation then return end  -- stale tick from a stopped phase
  if state.remaining_seconds > 0 then
    state.remaining_seconds = state.remaining_seconds - 1

    -- Notification check: fire when remaining_seconds crosses below the next threshold
    if state.notify_idx <= #state.notify_targets
        and state.remaining_seconds <= state.notify_targets[state.notify_idx] then
      local label = phase_labels[state.phase] or "Pomodoro"
      vim.notify(
        label .. ": " .. M._format_time(state.remaining_seconds) .. " remaining",
        vim.log.levels.INFO,
        { title = "Pomodoro" }
      )
      state.notify_idx = state.notify_idx + 1
    end

    -- Blink: start blink timer the first time remaining_seconds enters the last minute
    if state.remaining_seconds <= 60 and not state.blink_handle then
      state.blink_handle = uv.new_timer()
      state.blink_handle:start(
        state.config.blink_interval_ms,
        state.config.blink_interval_ms,
        vim.schedule_wrap(function()
          state.blink_visible = not state.blink_visible
        end)
      )
    end
  else
    stop_handle()
    stop_blink_handle()
    if state.phase == "work" then
      state.set_count       = state.set_count + 1
      state.daily_pomodoros = state.daily_pomodoros + 1
      M._save_daily_counts()
      if state.set_count >= state.config.long_break_interval then
        state.set_count = 0
        vim.notify("Time's up! Take a long break.", vim.log.levels.INFO, { title = "Pomodoro" })
        M._start_phase("long_break")
      else
        vim.notify("Time's up! Take a break.", vim.log.levels.INFO, { title = "Pomodoro" })
        M._start_phase("break")
      end
    elseif state.phase == "break" then
      state.daily_breaks = state.daily_breaks + 1
      M._save_daily_counts()
      state.running = false
      state.phase   = "idle"
      vim.notify("Break over! Ready to focus?", vim.log.levels.INFO, { title = "Pomodoro" })
    else  -- long_break
      state.daily_long_breaks = state.daily_long_breaks + 1
      M._save_daily_counts()
      state.running = false
      state.phase   = "idle"
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
  stop_blink_handle()
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

  -- Compute notification targets for this phase
  state.total_seconds = state.remaining_seconds
  local raw = {}
  for _, v in ipairs(state.config.notify_at or {}) do
    local t
    if v <= 1 then
      t = math.floor(state.total_seconds * (1 - v))
    else
      t = math.floor(v)
    end
    if t >= 0 and t < state.total_seconds then
      raw[#raw + 1] = t
    end
  end
  table.sort(raw, function(a, b) return a > b end)
  local seen = {}
  state.notify_targets = {}
  for _, t in ipairs(raw) do
    if not seen[t] then
      seen[t] = true
      state.notify_targets[#state.notify_targets + 1] = t
    end
  end
  state.notify_idx = 1

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
  stop_blink_handle()
  state.running = false
  state.phase = "idle"
  state.remaining_seconds = 0
end

function M.skip()
  if not state.running then return end
  stop_handle()
  stop_blink_handle()
  if state.phase == "work" then
    -- Decide break type the same way _tick would.
    -- Skipping is NOT counted as a completed pomodoro:
    -- daily_pomodoros and set_count do NOT increment on skip.
    local would_be = state.set_count + 1
    if would_be >= state.config.long_break_interval then
      state.set_count = 0
      vim.notify("Work skipped. Take a long break.", vim.log.levels.INFO, { title = "Pomodoro" })
      M._start_phase("long_break")
    else
      vim.notify("Work skipped. Take a break.", vim.log.levels.INFO, { title = "Pomodoro" })
      M._start_phase("break")
    end
  else
    -- break or long_break → back to idle
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
    -- Extract internal test options before merging into config
    local daily_file = opts._daily_file
    local config_opts = vim.tbl_extend("keep", {}, opts)
    config_opts._daily_file = nil
    if next(config_opts) ~= nil then
      state.config = vim.tbl_deep_extend("force", state.config, config_opts)
    end
    M._load_daily_counts(daily_file)
  else
    M._load_daily_counts()
  end

  vim.api.nvim_create_user_command("PomodoroStart",  function() M.start()  end, { force = true })
  vim.api.nvim_create_user_command("PomodoroStop",   function() M.stop()   end, { force = true })
  vim.api.nvim_create_user_command("PomodoroSkip",   function() M.skip()   end, { force = true })
  vim.api.nvim_create_user_command("PomodoroToggle", function() M.toggle() end, { force = true })
end

return M
