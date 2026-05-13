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

  lcd.invalidate()
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  lcd.color(lcd.RGB(255, 255, 255))

  local vStr   = widget.voltage  and string.format("%.2f V", widget.voltage) or "-- V"
  local pctStr = widget.pct      and string.format("%d%%", math.floor(widget.pct + 0.5)) or "-- %"
  local cellStr= widget.cellCount and (widget.cellCount .. "S") or "--S"

  lcd.drawText(4,   4, pctStr,  LEFT)
  lcd.drawText(4,  30, vStr,    LEFT)
  lcd.drawText(4,  56, cellStr, LEFT)
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
