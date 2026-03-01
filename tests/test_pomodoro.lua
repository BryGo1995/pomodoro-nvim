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

describe("load_config", function()
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
end)
