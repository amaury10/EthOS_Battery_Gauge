local M = {}

-- Discharge curves: voltsPerCell -> percent. Each table is sorted descending by v.
M.curves = {
  LiPo = {
    {v = 4.20, pct = 100},
    {v = 4.10, pct = 90},
    {v = 4.00, pct = 80},
    {v = 3.90, pct = 70},
    {v = 3.85, pct = 60},
    {v = 3.82, pct = 50},
    {v = 3.79, pct = 40},
    {v = 3.77, pct = 30},
    {v = 3.73, pct = 20},
    {v = 3.70, pct = 10},
    {v = 3.30, pct = 0},
  },
  LiHV = {
    {v = 4.35, pct = 100},
    {v = 4.25, pct = 90},
    {v = 4.15, pct = 80},
    {v = 4.05, pct = 70},
    {v = 4.00, pct = 60},
    {v = 3.97, pct = 50},
    {v = 3.94, pct = 40},
    {v = 3.92, pct = 30},
    {v = 3.88, pct = 20},
    {v = 3.85, pct = 10},
    {v = 3.30, pct = 0},
  },
  ["Li-Ion"] = {
    {v = 4.20, pct = 100},
    {v = 4.06, pct = 90},
    {v = 3.98, pct = 80},
    {v = 3.92, pct = 70},
    {v = 3.87, pct = 60},
    {v = 3.82, pct = 50},
    {v = 3.79, pct = 40},
    {v = 3.71, pct = 30},
    {v = 3.59, pct = 20},
    {v = 3.45, pct = 10},
    {v = 2.80, pct = 0},
  },
}

-- Max voltage per cell, used by cells.lua to estimate cell count
M.maxVoltage = {
  LiPo    = 4.25,
  LiHV    = 4.40,
  ["Li-Ion"] = 4.25,
}

function M.percent(chemistryName, voltsPerCell)
  local curve = M.curves[chemistryName]
  if not curve then return nil end
  if voltsPerCell >= curve[1].v then return 100 end
  if voltsPerCell <= curve[#curve].v then return 0 end
  for i = 1, #curve - 1 do
    local high, low = curve[i], curve[i+1]
    if voltsPerCell <= high.v and voltsPerCell >= low.v then
      local t = (voltsPerCell - low.v) / (high.v - low.v)
      return low.pct + t * (high.pct - low.pct)
    end
  end
  return nil
end

return M
