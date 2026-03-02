local pomodoro = require("pomodoro")

describe("format_time", function()
  it("formats zero as 00:00", function()
    assert.equals("00:00", pomodoro._format_time(0))
  end)

  it("formats 90 seconds as 01:30", function()
    assert.equals("01:30", pomodoro._format_time(90))
  end)

  it("formats 25 minutes (1500 seconds) as 25:00", function()
    assert.equals("25:00", pomodoro._format_time(1500))
  end)

  it("formats 5 minutes (300 seconds) as 05:00", function()
    assert.equals("05:00", pomodoro._format_time(300))
  end)
end)

describe("statusline", function()
  before_each(function()
    -- Ensure stopped state and default config before each test
    pomodoro._reset_state()
    pomodoro._load_config("/nonexistent/path/reset")
  end)

  it("returns empty string when not running", function()
    assert.equals("", pomodoro.statusline())
  end)

  it("returns work icon, count, dots and time when in work phase", function()
    pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 1500, set_count = 0, daily_pomodoros = 0 })
    assert.equals("🍅×0 ○○○○ 25:00", pomodoro.statusline())
  end)

  it("returns break icon, count, dots and time when in break phase", function()
    pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 300, set_count = 0, daily_breaks = 0 })
    assert.equals("☕×0 ○○○○ 05:00", pomodoro.statusline())
  end)

  it("returns moon icon and count and time when in long_break phase", function()
    pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 900, set_count = 0, daily_long_breaks = 0 })
    assert.equals("🌙×0 15:00", pomodoro.statusline())
  end)

  it("shows filled dots for completed sessions", function()
    pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 1500, set_count = 2, daily_pomodoros = 5 })
    assert.equals("🍅×5 ●●○○ 25:00", pomodoro.statusline())
  end)

  it("shows daily_pomodoros in statusline during work phase", function()
    pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 1500, set_count = 0, daily_pomodoros = 12 })
    assert.equals("🍅×12 ○○○○ 25:00", pomodoro.statusline())
  end)

  it("returns empty string after stop", function()
    pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 100 })
    pomodoro._reset_state()
    assert.equals("", pomodoro.statusline())
  end)

  it("shows filled dots during break phase for completed sessions", function()
    pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 300, set_count = 2, daily_breaks = 3 })
    assert.equals("☕×3 ●●○○ 05:00", pomodoro.statusline())
  end)

  it("dot count respects long_break_interval config", function()
    pomodoro._set_state({
      running = true, phase = "work",
      remaining_seconds = 1500, set_count = 1, daily_pomodoros = 1,
      config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15, long_break_interval = 3,
                 blink_interval_ms = 1000, notify_at = {} }
    })
    assert.equals("🍅×1 ●○○ 25:00", pomodoro.statusline())
  end)

  it("shows daily_breaks in statusline during break phase", function()
    pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 300, set_count = 0, daily_breaks = 7 })
    assert.equals("☕×7 ○○○○ 05:00", pomodoro.statusline())
  end)

  it("shows daily_long_breaks in statusline during long_break phase", function()
    pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 900, daily_long_breaks = 2 })
    assert.equals("🌙×2 15:00", pomodoro.statusline())
  end)

  describe("blink behaviour", function()
    it("hides time when blink_visible=false and remaining_seconds<=60", function()
      pomodoro._set_state({
        running = true, phase = "work", remaining_seconds = 30,
        set_count = 0, daily_pomodoros = 0, blink_visible = false,
      })
      assert.equals("🍅×0 ○○○○", pomodoro.statusline())
    end)

    it("shows time when blink_visible=true even with remaining_seconds<=60", function()
      pomodoro._set_state({
        running = true, phase = "work", remaining_seconds = 30,
        set_count = 0, daily_pomodoros = 0, blink_visible = true,
      })
      assert.equals("🍅×0 ○○○○ 00:30", pomodoro.statusline())
    end)

    it("shows time when blink_visible=false but remaining_seconds>60", function()
      pomodoro._set_state({
        running = true, phase = "work", remaining_seconds = 100,
        set_count = 0, daily_pomodoros = 0, blink_visible = false,
      })
      assert.equals("🍅×0 ○○○○ 01:40", pomodoro.statusline())
    end)

    it("hides time in break phase when blinking off", function()
      pomodoro._set_state({
        running = true, phase = "break", remaining_seconds = 30,
        set_count = 0, daily_breaks = 1, blink_visible = false,
      })
      assert.equals("☕×1 ○○○○", pomodoro.statusline())
    end)

    it("hides time in long_break phase when blinking off", function()
      pomodoro._set_state({
        running = true, phase = "long_break", remaining_seconds = 30,
        daily_long_breaks = 1, blink_visible = false,
      })
      assert.equals("🌙×1", pomodoro.statusline())
    end)
  end)
end)

describe("load_config", function()
  before_each(function()
    pomodoro._reset_state()
    pomodoro._load_config("/nonexistent/path/reset")
  end)

  it("uses defaults when config file does not exist", function()
    pomodoro._load_config("/nonexistent/path/pomodoro.lua")
    assert.equals(25, pomodoro._get_config().work_minutes)
    assert.equals(5, pomodoro._get_config().break_minutes)
  end)

  it("loads work_minutes from config file", function()
    local tmp = vim.fn.tempname() .. ".lua"
    local f = io.open(tmp, "w")
    f:write("return { work_minutes = 50, break_minutes = 10 }")
    f:close()
    pomodoro._load_config(tmp)
    assert.equals(50, pomodoro._get_config().work_minutes)
    assert.equals(10, pomodoro._get_config().break_minutes)
    os.remove(tmp)
  end)

  it("falls back to defaults for missing keys in config file", function()
    local tmp = vim.fn.tempname() .. ".lua"
    local f = io.open(tmp, "w")
    f:write("return { work_minutes = 45 }")
    f:close()
    pomodoro._load_config(tmp)
    assert.equals(45, pomodoro._get_config().work_minutes)
    assert.equals(5, pomodoro._get_config().break_minutes)
    os.remove(tmp)
  end)

  it("falls back to defaults when config file has a syntax error", function()
    local tmp = vim.fn.tempname() .. ".lua"
    local f = io.open(tmp, "w")
    f:write("return {{{")
    f:close()
    pomodoro._load_config(tmp)
    assert.equals(25, pomodoro._get_config().work_minutes)
    assert.equals(5, pomodoro._get_config().break_minutes)
    os.remove(tmp)
  end)

  it("has default long_break_minutes of 15", function()
    pomodoro._load_config("/nonexistent/path/reset")
    assert.equals(15, pomodoro._get_config().long_break_minutes)
  end)

  it("has default long_break_interval of 4", function()
    pomodoro._load_config("/nonexistent/path/reset")
    assert.equals(4, pomodoro._get_config().long_break_interval)
  end)

  it("has default blink_interval_ms of 1000", function()
    pomodoro._load_config("/nonexistent/path/reset")
    assert.equals(1000, pomodoro._get_config().blink_interval_ms)
  end)

  it("has default notify_at table", function()
    pomodoro._load_config("/nonexistent/path/reset")
    local na = pomodoro._get_config().notify_at
    assert.is_not_nil(na)
    assert.equals("table", type(na))
  end)
end)

describe("timer state transitions", function()
  before_each(function()
    pomodoro._reset_state()
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15, long_break_interval = 4,
                                     blink_interval_ms = 1000, notify_at = {} } })
  end)

  describe("start()", function()
    it("sets running to true", function()
      pomodoro._start_phase("work")
      assert.is_true(pomodoro._get_state().running)
    end)

    it("sets remaining_seconds to work_minutes * 60", function()
      pomodoro._start_phase("work")
      assert.equals(25 * 60, pomodoro._get_state().remaining_seconds)
    end)

    it("sets phase to work for work phase", function()
      pomodoro._start_phase("work")
      assert.equals("work", pomodoro._get_state().phase)
    end)

    it("sets remaining_seconds to break_minutes * 60 for break phase", function()
      pomodoro._start_phase("break")
      assert.equals(5 * 60, pomodoro._get_state().remaining_seconds)
    end)

    it("sets remaining_seconds to long_break_minutes * 60 for long_break phase", function()
      pomodoro._start_phase("long_break")
      assert.equals(15 * 60, pomodoro._get_state().remaining_seconds)
    end)

    it("resets blink_visible to true", function()
      pomodoro._set_state({ blink_visible = false })
      pomodoro._start_phase("work")
      assert.is_true(pomodoro._get_state().blink_visible)
    end)

    it("sets total_seconds equal to remaining_seconds", function()
      pomodoro._start_phase("work")
      local s = pomodoro._get_state()
      assert.equals(s.remaining_seconds, s.total_seconds)
    end)

    it("resets notify_idx to 1", function()
      pomodoro._set_state({ notify_idx = 5 })
      pomodoro._start_phase("work")
      assert.equals(1, pomodoro._get_state().notify_idx)
    end)
  end)

  describe("stop()", function()
    it("sets running to false", function()
      pomodoro._start_phase("work")
      pomodoro.stop()
      assert.is_false(pomodoro._get_state().running)
    end)

    it("resets remaining_seconds to 0", function()
      pomodoro._start_phase("work")
      pomodoro.stop()
      assert.equals(0, pomodoro._get_state().remaining_seconds)
    end)

    it("resets phase to idle", function()
      pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 100 })
      pomodoro.stop()
      assert.equals("idle", pomodoro._get_state().phase)
    end)

    it("resets blink_visible to true", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 30, blink_visible = false })
      pomodoro.stop()
      assert.is_true(pomodoro._get_state().blink_visible)
    end)
  end)

  describe("tick()", function()
    it("decrements remaining_seconds by 1", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 100 })
      pomodoro._tick(0)  -- gen=0 since _reset_state resets _generation to 0
      assert.equals(99, pomodoro._get_state().remaining_seconds)
    end)

    it("does not go below 0", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 0 })
      pomodoro._tick(0)  -- gen=0 since _reset_state resets _generation to 0
      assert.is_true(pomodoro._get_state().remaining_seconds >= 0)
    end)

    it("when work hits 0: increments set_count and daily_pomodoros", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 0, set_count = 1, daily_pomodoros = 3 })
      pomodoro._tick(0)
      assert.equals(2, pomodoro._get_state().set_count)
      assert.equals(4, pomodoro._get_state().daily_pomodoros)
    end)

    it("when work hits 0 and set_count < interval: starts short break", function()
      -- set_count = 2, interval = 4: post-increment = 3, check is 3 >= 4 → false → short break
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 0, set_count = 2 })
      pomodoro._tick(0)
      local s = pomodoro._get_state()
      assert.equals("break", s.phase)
      assert.is_true(s.running)
      assert.equals(5 * 60, s.remaining_seconds)
    end)

    it("when work hits 0 and set_count reaches interval: starts long break and resets set_count", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 0, set_count = 3 })
      pomodoro._tick(0)
      local s = pomodoro._get_state()
      assert.equals("long_break", s.phase)
      assert.equals(0, s.set_count)
      assert.is_true(s.running)
      assert.equals(15 * 60, s.remaining_seconds)
    end)

    it("when break hits 0: stops timer and sets phase to idle", function()
      pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 0 })
      pomodoro._tick(0)
      local s = pomodoro._get_state()
      assert.is_false(s.running)
      assert.equals("idle", s.phase)
    end)

    it("when break hits 0: increments daily_breaks", function()
      pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 0, daily_breaks = 2 })
      pomodoro._tick(0)
      assert.equals(3, pomodoro._get_state().daily_breaks)
    end)

    it("when long_break hits 0: stops timer and sets phase to idle", function()
      pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 0 })
      pomodoro._tick(0)
      local s = pomodoro._get_state()
      assert.is_false(s.running)
      assert.equals("idle", s.phase)
    end)

    it("when long_break hits 0: increments daily_long_breaks", function()
      pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 0, daily_long_breaks = 1 })
      pomodoro._tick(0)
      assert.equals(2, pomodoro._get_state().daily_long_breaks)
    end)

    it("sets blink_handle when remaining_seconds reaches 60", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 61 })
      pomodoro._tick(0)  -- remaining becomes 60; blink_handle should be set
      assert.is_not_nil(pomodoro._get_state().blink_handle)
    end)

    it("does not start a second blink_handle when one is already running", function()
      local mock_handle = { stop = function() end, close = function() end }
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 30, blink_handle = mock_handle })
      pomodoro._tick(0)
      assert.equals(mock_handle, pomodoro._get_state().blink_handle)
    end)
  end)

  describe("skip()", function()
    it("during work phase starts break", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 500 })
      pomodoro.skip()
      assert.equals("break", pomodoro._get_state().phase)
      assert.is_true(pomodoro._get_state().running)
      assert.equals(0, pomodoro._get_state().daily_pomodoros)  -- skip does not count
    end)

    it("during break phase stops timer", function()
      pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 100 })
      pomodoro.skip()
      assert.is_false(pomodoro._get_state().running)
    end)

    it("does nothing when not running", function()
      pomodoro._reset_state()
      pomodoro.skip()
      assert.is_false(pomodoro._get_state().running)
      assert.equals("idle", pomodoro._get_state().phase)
      assert.equals(0, pomodoro._get_state().remaining_seconds)
    end)

    it("during work phase: starts long_break when set_count would reach interval", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 500, set_count = 3 })
      pomodoro.skip()
      assert.equals("long_break", pomodoro._get_state().phase)
      assert.is_true(pomodoro._get_state().running)
      assert.equals(0, pomodoro._get_state().set_count)
      assert.equals(0, pomodoro._get_state().daily_pomodoros)  -- skip does not count
    end)

    it("during long_break phase: stops timer and sets phase to idle", function()
      pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 100 })
      pomodoro.skip()
      assert.is_false(pomodoro._get_state().running)
      assert.equals("idle", pomodoro._get_state().phase)
    end)

    it("resets blink_visible to true", function()
      pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 30, blink_visible = false })
      pomodoro.skip()
      assert.is_true(pomodoro._get_state().blink_visible)
    end)
  end)

  describe("toggle()", function()
    it("stops when running", function()
      pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 500 })
      pomodoro.toggle()
      assert.is_false(pomodoro._get_state().running)
    end)

    it("starts when not running", function()
      pomodoro._reset_state()
      pomodoro.toggle()
      assert.is_true(pomodoro._get_state().running)
    end)
  end)
end)

describe("notify_targets computation", function()
  before_each(function()
    pomodoro._reset_state()
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = { 0.5, 0.75, 60 } } })
  end)

  it("computes correct targets for 25-min work phase", function()
    pomodoro._start_phase("work")
    local s = pomodoro._get_state()
    assert.same({ 750, 375, 60 }, s.notify_targets)
    assert.equals(1, s.notify_idx)
  end)

  it("computes correct targets for 5-min break phase", function()
    pomodoro._start_phase("break")
    local targets = pomodoro._get_state().notify_targets
    -- 0.5 → floor(300*0.5)=150; 0.75 → floor(300*0.25)=75; 60 → 60
    assert.same({ 150, 75, 60 }, targets)
  end)

  it("drops absolute thresholds >= total_seconds", function()
    pomodoro._set_state({ config = { work_minutes = 1, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = { 120 } } })  -- 120 >= 60 (1-min phase)
    pomodoro._start_phase("work")
    assert.same({}, pomodoro._get_state().notify_targets)
  end)

  it("keeps absolute thresholds < total_seconds", function()
    pomodoro._set_state({ config = { work_minutes = 5, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = { 60 } } })  -- 60 < 300
    pomodoro._start_phase("work")
    assert.same({ 60 }, pomodoro._get_state().notify_targets)
  end)

  it("deduplicates targets that resolve to the same second", function()
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = { 0.5, 0.5 } } })
    pomodoro._start_phase("work")
    local targets = pomodoro._get_state().notify_targets
    assert.equals(1, #targets)
    assert.equals(750, targets[1])
  end)

  it("produces empty targets when notify_at is empty", function()
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = {} } })
    pomodoro._start_phase("work")
    assert.same({}, pomodoro._get_state().notify_targets)
  end)

  it("targets are sorted descending", function()
    -- notify_at in ascending order → targets should still be descending
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = { 60, 0.75, 0.5 } } })
    pomodoro._start_phase("work")
    local targets = pomodoro._get_state().notify_targets
    for i = 1, #targets - 1 do
      assert.is_true(targets[i] > targets[i + 1])
    end
  end)
end)

describe("notification firing", function()
  local notifications
  local orig_notify

  before_each(function()
    pomodoro._reset_state()
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = {} } })
    notifications = {}
    orig_notify = vim.notify
    vim.notify = function(msg, ...) table.insert(notifications, msg) end
  end)

  after_each(function()
    vim.notify = orig_notify
  end)

  it("fires notification when remaining_seconds reaches a target", function()
    pomodoro._set_state({
      running = true, phase = "work", remaining_seconds = 61,
      total_seconds = 1500, notify_targets = { 60 }, notify_idx = 1,
    })
    pomodoro._tick(0)  -- remaining becomes 60, threshold crossed
    assert.equals(1, #notifications)
    assert.truthy(notifications[1]:find("Pomodoro"))
    assert.truthy(notifications[1]:find("01:00"))
    assert.equals(2, pomodoro._get_state().notify_idx)
  end)

  it("does not fire when remaining_seconds is above threshold", function()
    pomodoro._set_state({
      running = true, phase = "work", remaining_seconds = 100,
      total_seconds = 1500, notify_targets = { 60 }, notify_idx = 1,
    })
    pomodoro._tick(0)  -- remaining becomes 99, above threshold
    assert.equals(0, #notifications)
    assert.equals(1, pomodoro._get_state().notify_idx)
  end)

  it("fires at most one notification per tick", function()
    -- Two targets very close together; only one fires per tick
    pomodoro._set_state({
      running = true, phase = "work", remaining_seconds = 62,
      total_seconds = 1500, notify_targets = { 61, 60 }, notify_idx = 1,
    })
    pomodoro._tick(0)  -- remaining becomes 61, first target hit
    assert.equals(1, #notifications)
    assert.equals(2, pomodoro._get_state().notify_idx)
  end)

  it("uses 'Pomodoro' label for work phase", function()
    pomodoro._set_state({
      running = true, phase = "work", remaining_seconds = 61,
      total_seconds = 1500, notify_targets = { 60 }, notify_idx = 1,
    })
    pomodoro._tick(0)
    assert.truthy(notifications[1]:find("^Pomodoro: "))
  end)

  it("uses 'Break' label for break phase", function()
    pomodoro._set_state({
      running = true, phase = "break", remaining_seconds = 61,
      total_seconds = 300, notify_targets = { 60 }, notify_idx = 1,
    })
    pomodoro._tick(0)
    assert.truthy(notifications[1]:find("^Break: "))
  end)

  it("uses 'Long break' label for long_break phase", function()
    pomodoro._set_state({
      running = true, phase = "long_break", remaining_seconds = 61,
      total_seconds = 900, notify_targets = { 60 }, notify_idx = 1,
    })
    pomodoro._tick(0)
    assert.truthy(notifications[1]:find("^Long break: "))
  end)

  it("includes formatted time remaining in notification", function()
    pomodoro._set_state({
      running = true, phase = "work", remaining_seconds = 751,
      total_seconds = 1500, notify_targets = { 750 }, notify_idx = 1,
    })
    pomodoro._tick(0)  -- remaining becomes 750 = 12:30
    assert.truthy(notifications[1]:find("12:30 remaining"))
  end)

  it("advances notify_idx after each fired notification", function()
    pomodoro._set_state({
      running = true, phase = "work", remaining_seconds = 61,
      total_seconds = 1500, notify_targets = { 60, 30 }, notify_idx = 1,
    })
    pomodoro._tick(0)  -- fires first (60)
    assert.equals(2, pomodoro._get_state().notify_idx)
  end)
end)

describe("per-counter incrementing (natural completion only)", function()
  local orig_notify

  before_each(function()
    pomodoro._reset_state()
    pomodoro._set_state({ config = { work_minutes = 25, break_minutes = 5, long_break_minutes = 15,
                                     long_break_interval = 4, blink_interval_ms = 1000,
                                     notify_at = {} } })
    orig_notify = vim.notify
    vim.notify = function() end
  end)

  after_each(function()
    vim.notify = orig_notify
  end)

  it("increments daily_pomodoros when work completes naturally", function()
    pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 0, set_count = 0, daily_pomodoros = 2 })
    pomodoro._tick(0)
    assert.equals(3, pomodoro._get_state().daily_pomodoros)
  end)

  it("does NOT increment daily_pomodoros on skip", function()
    pomodoro._set_state({ running = true, phase = "work", remaining_seconds = 500, daily_pomodoros = 2 })
    pomodoro.skip()
    assert.equals(2, pomodoro._get_state().daily_pomodoros)
  end)

  it("increments daily_breaks when break completes naturally", function()
    pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 0, daily_breaks = 1 })
    pomodoro._tick(0)
    assert.equals(2, pomodoro._get_state().daily_breaks)
  end)

  it("does NOT increment daily_breaks on skip", function()
    pomodoro._set_state({ running = true, phase = "break", remaining_seconds = 100, daily_breaks = 1 })
    pomodoro.skip()
    assert.equals(1, pomodoro._get_state().daily_breaks)
  end)

  it("increments daily_long_breaks when long_break completes naturally", function()
    pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 0, daily_long_breaks = 0 })
    pomodoro._tick(0)
    assert.equals(1, pomodoro._get_state().daily_long_breaks)
  end)

  it("does NOT increment daily_long_breaks on skip", function()
    pomodoro._set_state({ running = true, phase = "long_break", remaining_seconds = 100, daily_long_breaks = 0 })
    pomodoro.skip()
    assert.equals(0, pomodoro._get_state().daily_long_breaks)
  end)
end)

describe("setup()", function()
  before_each(function()
    pomodoro._reset_state()
  end)

  it("registers PomodoroStart command", function()
    pomodoro.setup()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds["PomodoroStart"])
  end)

  it("registers PomodoroStop command", function()
    pomodoro.setup()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds["PomodoroStop"])
  end)

  it("registers PomodoroSkip command", function()
    pomodoro.setup()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds["PomodoroSkip"])
  end)

  it("registers PomodoroToggle command", function()
    pomodoro.setup()
    local cmds = vim.api.nvim_get_commands({})
    assert.is_not_nil(cmds["PomodoroToggle"])
  end)

  it("accepts inline opts to override config", function()
    pomodoro.setup({ work_minutes = 45, break_minutes = 10 })
    assert.equals(45, pomodoro._get_config().work_minutes)
    assert.equals(10, pomodoro._get_config().break_minutes)
  end)

  it("can be called twice without error", function()
    pomodoro.setup()
    assert.has_no.errors(function() pomodoro.setup() end)
  end)

  it("loads daily counts from disk on setup (new schema)", function()
    local tmp = vim.fn.tempname() .. ".json"
    local today = os.date("%Y-%m-%d")
    vim.fn.writefile({ vim.fn.json_encode({ date = today, pomodoros = 5, breaks = 3, long_breaks = 1 }) }, tmp)
    pomodoro.setup({ _daily_file = tmp })
    local s = pomodoro._get_state()
    assert.equals(5, s.daily_pomodoros)
    assert.equals(3, s.daily_breaks)
    assert.equals(1, s.daily_long_breaks)
    os.remove(tmp)
  end)

  it("loads daily count from disk on setup (old schema: count → pomodoros)", function()
    local tmp = vim.fn.tempname() .. ".json"
    local today = os.date("%Y-%m-%d")
    vim.fn.writefile({ vim.fn.json_encode({ date = today, count = 9 }) }, tmp)
    pomodoro.setup({ _daily_file = tmp })
    local s = pomodoro._get_state()
    assert.equals(9, s.daily_pomodoros)
    assert.equals(0, s.daily_breaks)
    assert.equals(0, s.daily_long_breaks)
    os.remove(tmp)
  end)
end)

describe("persistence", function()
  local tmp_path

  before_each(function()
    pomodoro._reset_state()
    tmp_path = vim.fn.tempname() .. ".json"
  end)

  after_each(function()
    os.remove(tmp_path)
  end)

  it("_save_daily_counts writes date and all three counters", function()
    pomodoro._set_state({ daily_pomodoros = 7, daily_breaks = 4, daily_long_breaks = 2 })
    pomodoro._save_daily_counts(tmp_path)
    local lines = vim.fn.readfile(tmp_path)
    local data = vim.fn.json_decode(lines[1])
    assert.equals(os.date("%Y-%m-%d"), data.date)
    assert.equals(7, data.pomodoros)
    assert.equals(4, data.breaks)
    assert.equals(2, data.long_breaks)
  end)

  it("_load_daily_counts restores all counters when date matches today (new schema)", function()
    local today = os.date("%Y-%m-%d")
    vim.fn.writefile({ vim.fn.json_encode({ date = today, pomodoros = 12, breaks = 5, long_breaks = 3 }) }, tmp_path)
    pomodoro._load_daily_counts(tmp_path)
    local s = pomodoro._get_state()
    assert.equals(12, s.daily_pomodoros)
    assert.equals(5, s.daily_breaks)
    assert.equals(3, s.daily_long_breaks)
  end)

  it("_load_daily_counts handles old schema: maps count to daily_pomodoros", function()
    local today = os.date("%Y-%m-%d")
    vim.fn.writefile({ vim.fn.json_encode({ date = today, count = 8 }) }, tmp_path)
    pomodoro._load_daily_counts(tmp_path)
    local s = pomodoro._get_state()
    assert.equals(8, s.daily_pomodoros)
    assert.equals(0, s.daily_breaks)
    assert.equals(0, s.daily_long_breaks)
  end)

  it("_load_daily_counts resets nothing when stored date is different", function()
    vim.fn.writefile({ vim.fn.json_encode({ date = "2020-01-01", pomodoros = 12, breaks = 5, long_breaks = 3 }) }, tmp_path)
    pomodoro._load_daily_counts(tmp_path)
    local s = pomodoro._get_state()
    assert.equals(0, s.daily_pomodoros)
    assert.equals(0, s.daily_breaks)
    assert.equals(0, s.daily_long_breaks)
  end)

  it("_load_daily_counts gracefully handles missing file", function()
    pomodoro._load_daily_counts("/nonexistent/path.json")
    assert.equals(0, pomodoro._get_state().daily_pomodoros)
  end)

  it("_load_daily_counts gracefully handles malformed file", function()
    vim.fn.writefile({ "not json" }, tmp_path)
    pomodoro._load_daily_counts(tmp_path)
    assert.equals(0, pomodoro._get_state().daily_pomodoros)
  end)

  it("_save_daily_counts does not raise on unwritable path", function()
    assert.has_no.errors(function()
      pomodoro._save_daily_counts("/nonexistent/dir/pomodoro-daily.json")
    end)
  end)

  it("round-trip: save and reload preserves all counters", function()
    pomodoro._set_state({ daily_pomodoros = 3, daily_breaks = 2, daily_long_breaks = 1 })
    pomodoro._save_daily_counts(tmp_path)
    pomodoro._set_state({ daily_pomodoros = 0, daily_breaks = 0, daily_long_breaks = 0 })
    pomodoro._load_daily_counts(tmp_path)
    local s = pomodoro._get_state()
    assert.equals(3, s.daily_pomodoros)
    assert.equals(2, s.daily_breaks)
    assert.equals(1, s.daily_long_breaks)
  end)
end)
