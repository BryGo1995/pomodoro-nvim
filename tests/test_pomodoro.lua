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
    -- Ensure stopped state before each test
    pomodoro._reset_state()
  end)

  it("returns empty string when not running", function()
    assert.equals("", pomodoro.statusline())
  end)

  it("returns work icon and time when in work phase", function()
    pomodoro._set_state({ running = true, is_break = false, remaining_seconds = 1500 })
    assert.equals("🍅 25:00", pomodoro.statusline())
  end)

  it("returns break icon and time when in break phase", function()
    pomodoro._set_state({ running = true, is_break = true, remaining_seconds = 300 })
    assert.equals("☕ 05:00", pomodoro.statusline())
  end)

  it("returns empty string after stop", function()
    pomodoro._set_state({ running = true, is_break = false, remaining_seconds = 100 })
    pomodoro._reset_state()
    assert.equals("", pomodoro.statusline())
  end)
end)
