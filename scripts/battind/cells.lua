local M = {}

local SAMPLE_COUNT          = 3      -- need this many stable samples to detect
local STABILITY_THRESHOLD_V = 0.1    -- max-min over the window must be <= this
local REDETECT_DELTA_V_CELL = 0.5    -- per-cell jump that triggers re-detection

function M.new()
  return {
    samples           = {},
    detectedCells     = nil,
    lastStableVoltage = nil,
  }
end

function M.reset(state)
  state.samples = {}
  state.detectedCells = nil
  state.lastStableVoltage = nil
end

local function push(state, voltage)
  state.samples[#state.samples + 1] = voltage
  if #state.samples > SAMPLE_COUNT then
    table.remove(state.samples, 1)
  end
end

local function windowStable(state)
  local lo, hi = state.samples[1], state.samples[1]
  for i = 2, #state.samples do
    if state.samples[i] < lo then lo = state.samples[i] end
    if state.samples[i] > hi then hi = state.samples[i] end
  end
  return (hi - lo) <= STABILITY_THRESHOLD_V
end

function M.update(state, voltage, maxVoltagePerCell)
  -- Invalid voltage resets the window but keeps last detection
  if voltage == nil or voltage <= 0 then
    state.samples = {}
    return state.detectedCells
  end

  push(state, voltage)

  if #state.samples < SAMPLE_COUNT then
    return state.detectedCells
  end

  if not windowStable(state) then
    return state.detectedCells
  end

  -- Compute average over the stable window
  local sum = 0
  for i = 1, #state.samples do sum = sum + state.samples[i] end
  local avg = sum / #state.samples

  local newCells = math.ceil(avg / maxVoltagePerCell)

  if state.detectedCells == nil then
    state.detectedCells = newCells
    state.lastStableVoltage = avg
  else
    local deltaPerCell = math.abs(avg - state.lastStableVoltage) / state.detectedCells
    if deltaPerCell > REDETECT_DELTA_V_CELL then
      state.detectedCells = newCells
    end
    state.lastStableVoltage = avg
  end

  return state.detectedCells
end

return M
