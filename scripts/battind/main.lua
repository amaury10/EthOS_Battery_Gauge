local SCRIPT_DIR = "/scripts/battind/"
local chemistry  = assert(loadfile(SCRIPT_DIR .. "chemistry.lua"))()
local cells      = assert(loadfile(SCRIPT_DIR .. "cells.lua"))()

local CELL_CHOICES = {
  {"Auto", 0}, {"1S", 1}, {"2S", 2}, {"3S", 3}, {"4S", 4},
  {"5S", 5}, {"6S", 6}, {"8S", 8}, {"10S", 10}, {"12S", 12},
}

-- Ethos form.addChoiceField only accepts integer values; map IDs to chemistry names.
local CHEMISTRY_NAMES = {"LiPo", "LiHV", "Li-Ion"}
local CHEMISTRY_CHOICES = {
  {"LiPo", 1}, {"LiHV", 2}, {"Li-Ion", 3},
}

local AUDIO_CHOICES = {
  {"Off", 0}, {"5 s", 5}, {"10 s", 10}, {"15 s", 15},
  {"30 s", 30}, {"60 s", 60}, {"120 s", 120},
}

local function create()
  return {
    -- config (persisted)
    source       = nil,
    cellChoice   = 0,
    chemistry    = 1,
    audioPeriod  = 30,
    -- runtime (not persisted)
    detector     = cells.new(),
    voltage      = nil,
    cellCount    = nil,
    pct          = nil,
    lastAnnounce = 0,
    bootTime     = os.clock(),
  }
end

local function configure(widget)
  local line = form.addLine("Voltage source")
  form.addSourceField(line, nil,
    function() return widget.source end,
    function(v) widget.source = v end)

  line = form.addLine("Cell count")
  form.addChoiceField(line, nil, CELL_CHOICES,
    function() return widget.cellChoice end,
    function(v) widget.cellChoice = v end)

  line = form.addLine("Battery chemistry")
  form.addChoiceField(line, nil, CHEMISTRY_CHOICES,
    function() return widget.chemistry end,
    function(v) widget.chemistry = v end)

  line = form.addLine("Audio period")
  form.addChoiceField(line, nil, AUDIO_CHOICES,
    function() return widget.audioPeriod end,
    function(v) widget.audioPeriod = v end)
end

local function read(widget)
  widget.source      = storage.read("source")
  widget.cellChoice  = storage.read("cellChoice")  or 0
  widget.chemistry   = storage.read("chemistry")   or 1
  widget.audioPeriod = storage.read("audioPeriod") or 30
end

local function write(widget)
  storage.write("source",      widget.source)
  storage.write("cellChoice",  widget.cellChoice)
  storage.write("chemistry",   widget.chemistry)
  storage.write("audioPeriod", widget.audioPeriod)
end

local function wakeup(widget)
  local v = nil
  if widget.source then
    v = widget.source:value()
  end
  widget.voltage = v

  local chemName = CHEMISTRY_NAMES[widget.chemistry] or "LiPo"
  local maxV = chemistry.maxVoltage[chemName] or 4.25

  if widget.cellChoice and widget.cellChoice > 0 then
    widget.cellCount = widget.cellChoice
  else
    widget.cellCount = cells.update(widget.detector, v, maxV)
  end

  if v and v > 0 and widget.cellCount then
    local vPerCell = v / widget.cellCount
    widget.pct = chemistry.percent(chemName, vPerCell)
  else
    widget.pct = nil
  end

  -- Audio readout: skip if disabled, no telemetry, or before first interval since boot
  local now = os.clock()
  local period = widget.audioPeriod or 0
  if period > 0
      and widget.pct ~= nil
      and (now - widget.bootTime) >= period
      and (now - widget.lastAnnounce) >= period then
    system.playNumber(math.floor(widget.pct + 0.5), UNIT_PERCENT)
    widget.lastAnnounce = now
  end

  lcd.invalidate()
end

local COLOR_BG    = lcd.RGB(0,   0,   0)
local COLOR_FG    = lcd.RGB(255, 255, 255)
local COLOR_DIM   = lcd.RGB(120, 120, 120)
local COLOR_GREEN = lcd.RGB( 60, 200,  60)
local COLOR_AMBER = lcd.RGB(230, 170,   0)
local COLOR_RED   = lcd.RGB(220,  40,  40)

-- Defensive font helper: works whether or not lcd.font / FONT_* exist in this Ethos version
local function setFont(f)
  if type(lcd.font) == "function" and f ~= nil then
    lcd.font(f)
  end
end

local function gaugeColor(pct)
  if pct == nil then return COLOR_DIM end
  if pct >= 50 then return COLOR_GREEN end
  if pct >= 20 then return COLOR_AMBER end
  return COLOR_RED
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  lcd.color(COLOR_BG)
  lcd.drawFilledRectangle(0, 0, w, h)

  local pctStr  = widget.pct      and string.format("%d%%",   math.floor(widget.pct + 0.5)) or "-- %"
  local vStr    = widget.voltage  and string.format("%.2f V", widget.voltage)               or "-- V"
  local cellStr = widget.cellCount and (widget.cellCount .. "S") or "--S"

  local compact = (w < 320)

  if compact then
    -- Compact layout (X-Lite S)
    lcd.color(COLOR_FG)
    setFont(FONT_L)
    lcd.drawText(4, 2, pctStr, LEFT)
    setFont(FONT_S)
    lcd.drawText(w - 4, 6, cellStr .. "  " .. vStr, RIGHT)

    local barW = w - 8
    local barH = 12
    local barX = 4
    local barY = h - barH - 4
    lcd.color(COLOR_DIM)
    lcd.drawRectangle(barX, barY, barW, barH)
    if widget.pct then
      local fill = math.floor(barW * widget.pct / 100 + 0.5)
      lcd.color(gaugeColor(widget.pct))
      lcd.drawFilledRectangle(barX + 1, barY + 1, math.max(0, fill - 2), barH - 2)
    end
  else
    -- Large layout (X18 and up)
    lcd.color(COLOR_FG)
    setFont(FONT_XL)
    lcd.drawText(8, 4, pctStr, LEFT)
    setFont(FONT_L)
    lcd.drawText(w - 8, 4, vStr, RIGHT)
    setFont(FONT_STD)
    lcd.drawText(w - 8, 4 + 32, cellStr, RIGHT)

    local barW = w - 16
    local barH = 20
    local barX = 8
    local barY = h - barH - 8
    lcd.color(COLOR_DIM)
    lcd.drawRectangle(barX, barY, barW, barH)
    if widget.pct then
      local fill = math.floor(barW * widget.pct / 100 + 0.5)
      lcd.color(gaugeColor(widget.pct))
      lcd.drawFilledRectangle(barX + 2, barY + 2, math.max(0, fill - 4), barH - 4)
    end
  end
end

local function init()
  system.registerWidget({
    key        = "battind",
    name       = "Battery Indicator",
    create     = create,
    configure  = configure,
    read       = read,
    write      = write,
    wakeup     = wakeup,
    paint      = paint,
    title      = false,
    persistent = false,
  })
end

return { init = init }
