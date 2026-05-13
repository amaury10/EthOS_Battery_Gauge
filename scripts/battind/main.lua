local SCRIPT_DIR = "/scripts/battind/"
local chemistry  = assert(loadfile(SCRIPT_DIR .. "chemistry.lua"))()
local cells      = assert(loadfile(SCRIPT_DIR .. "cells.lua"))()

local CELL_CHOICES = {
  {"Auto", 0}, {"1S", 1}, {"2S", 2}, {"3S", 3}, {"4S", 4},
  {"5S", 5}, {"6S", 6}, {"8S", 8}, {"10S", 10}, {"12S", 12},
}

local CHEMISTRY_CHOICES = {
  {"LiPo", "LiPo"}, {"LiHV", "LiHV"}, {"Li-Ion", "Li-Ion"},
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
    chemistry    = "LiPo",
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
  widget.chemistry   = storage.read("chemistry")   or "LiPo"
  widget.audioPeriod = storage.read("audioPeriod") or 30
end

local function write(widget)
  storage.write("source",      widget.source)
  storage.write("cellChoice",  widget.cellChoice)
  storage.write("chemistry",   widget.chemistry)
  storage.write("audioPeriod", widget.audioPeriod)
end

local function wakeup(widget)
  -- (filled in Task 5)
end

local function paint(widget)
  local w, h = lcd.getWindowSize()
  lcd.color(lcd.RGB(255, 255, 255))
  lcd.drawText(4, 4, "BattInd (config only)", LEFT)
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
