# Battery Indicator Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** Construire un widget Ethos 26 affichant le niveau d'une batterie (à partir d'une source télémétrie de tension) avec annonce audio périodique configurable.

**Architecture :** Trois modules Lua. `chemistry.lua` et `cells.lua` contiennent la logique pure (interpolation V→%, détection automatique du nombre de cellules) et sont testés en TDD via Lua vanille. `main.lua` est la glue Ethos (registration, paint, wakeup, configure, persistance) — testée manuellement dans le simulateur Ethos Suite.

**Tech Stack :** Lua 5.x, API Ethos 26 (`system.registerWidget`, `form.*`, `lcd.*`, `storage.*`, `system.playNumber`), winget pour installer Lua, Ethos Suite (simulateur) pour les tests d'intégration.

---

## File Structure

Le dépôt `EthOS_Battery_Gauge` est déjà cloné dans `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\` avec un remote vers `https://github.com/amaury10/EthOS_Battery_Gauge.git` (branche `main`, aucun commit encore).

```
J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\
├── .git\                   -- déjà présent (cloné)
├── scripts\battind\
│   ├── main.lua            -- Widget registration + Ethos callbacks (paint, wakeup, configure, etc.)
│   ├── chemistry.lua       -- Battery chemistry tables and V/cell → % interpolation (pure)
│   └── cells.lua           -- Auto cell-count detection FSM (pure)
├── tests\
│   ├── test_chemistry.lua  -- Unit tests for chemistry.lua
│   ├── test_cells.lua      -- Unit tests for cells.lua
│   └── helpers.lua         -- assertNear, assertEqual
├── docs\superpowers\
│   ├── specs\2026-05-13-battery-indicator-design.md  -- (already exists)
│   └── plans\2026-05-13-battery-indicator.md         -- (this file)
├── .gitignore              -- créé en Task 1
└── README.md               -- Install, config, troubleshooting
```

**Boundaries :**
- `chemistry.lua` ne connaît rien du nombre de cellules. Il convertit V/cellule → %. Pur.
- `cells.lua` ne connaît rien de la chimie. Il prend une tension globale + V/cellule max et renvoie un nombre de cellules. Pur.
- `main.lua` orchestre tout : lit la télémétrie, alimente `cells.lua`, divise pour obtenir V/cellule, alimente `chemistry.lua`, dessine, joue l'audio.

---

## Task 1: Bootstrap projet

**Files :**
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\.gitignore`
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\` (directory)
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\` (directory)

- [ ] **Step 1.1: Vérifier l'état du dépôt cloné**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge status
git -C J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge remote -v
```

Expected : branche `main`, "No commits yet", remote `origin → https://github.com/amaury10/EthOS_Battery_Gauge.git`. Les fichiers spec et plan sous `docs/superpowers/` apparaissent comme untracked.

- [ ] **Step 1.2: Créer le .gitignore**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\.gitignore` with:
```
# Lua bytecode
*.luac

# Editor
.vscode/
.idea/
*.swp
*~

# OS
Thumbs.db
.DS_Store

# Build artifacts
dist/
```

- [ ] **Step 1.3: Créer les dossiers de code et tests**

Run:
```powershell
New-Item -ItemType Directory -Path J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind -Force
New-Item -ItemType Directory -Path J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests -Force
```

Expected : les deux dossiers existent.

- [ ] **Step 1.4: Installer Lua (winget)**

Run:
```powershell
winget install -e --id DEVCOM.Lua
```

Expected : installation réussie. Si winget pose une question de licence, accepter.

- [ ] **Step 1.5: Vérifier Lua**

Run (depuis un nouveau shell PowerShell pour que le PATH soit pris en compte) :
```powershell
lua -v
```

Expected : sortie comme `Lua 5.4.x  Copyright (C) 1994-...`. Si la commande n'est pas trouvée, ajouter manuellement le dossier d'install au PATH (typiquement `C:\Program Files (x86)\Lua\5.4\` ou similaire).

- [ ] **Step 1.6: Premier commit (initial)**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge add .gitignore docs/
git -C J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge commit -m "chore: bootstrap project structure with spec and plan"
```

Expected : un commit créé (le premier du dépôt). `git push` vers GitHub n'est PAS lancé automatiquement — uniquement quand l'utilisateur le demandera explicitement.

---

## Task 2: Module `chemistry.lua` (TDD)

**Files :**
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\helpers.lua`
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\test_chemistry.lua`
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\chemistry.lua`

- [ ] **Step 2.1: Créer `tests/helpers.lua`**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\helpers.lua` :
```lua
local M = {}

function M.assertEqual(actual, expected, msg)
  if actual ~= expected then
    error(string.format("FAIL: %s -- expected %s, got %s",
      tostring(msg or ""), tostring(expected), tostring(actual)), 2)
  end
  print(string.format("PASS: %s (got %s)", tostring(msg or ""), tostring(actual)))
end

function M.assertNear(actual, expected, tolerance, msg)
  tolerance = tolerance or 0.5
  if type(actual) ~= "number" then
    error(string.format("FAIL: %s -- expected number, got %s (%s)",
      tostring(msg or ""), tostring(actual), type(actual)), 2)
  end
  if math.abs(actual - expected) > tolerance then
    error(string.format("FAIL: %s -- expected ~%s (+/- %s), got %s",
      tostring(msg or ""), tostring(expected), tostring(tolerance), tostring(actual)), 2)
  end
  print(string.format("PASS: %s (got %s)", tostring(msg or ""), tostring(actual)))
end

return M
```

- [ ] **Step 2.2: Écrire le premier test (LiPo 100%)**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\test_chemistry.lua` :
```lua
package.path = "scripts/battind/?.lua;tests/?.lua;" .. package.path
local h = require("helpers")
local chemistry = require("chemistry")

h.assertNear(chemistry.percent("LiPo", 4.20), 100, 0.1, "LiPo 4.20V = 100%")

print("--- chemistry tests done ---")
```

- [ ] **Step 2.3: Lancer le test, vérifier qu'il échoue**

Run (depuis le répertoire racine du projet) :
```powershell
cd J:\_Dev\Perso\TestEthos
lua tests/test_chemistry.lua
```

Expected : erreur du type `module 'chemistry' not found`.

- [ ] **Step 2.4: Squelette minimal de `chemistry.lua` pour passer ce test**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\chemistry.lua` :
```lua
local M = {}

M.curves = {
  LiPo = {
    {v = 4.20, pct = 100},
    {v = 3.30, pct = 0},
  },
}

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
```

- [ ] **Step 2.5: Lancer le test, vérifier qu'il passe**

Run:
```powershell
lua tests/test_chemistry.lua
```

Expected : `PASS: LiPo 4.20V = 100% (got 100)` puis `--- chemistry tests done ---`.

- [ ] **Step 2.6: Étendre `test_chemistry.lua` avec tous les cas**

Replace `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\test_chemistry.lua` content with :
```lua
package.path = "scripts/battind/?.lua;tests/?.lua;" .. package.path
local h = require("helpers")
local chemistry = require("chemistry")

-- LiPo boundary
h.assertNear(chemistry.percent("LiPo", 4.20), 100, 0.1, "LiPo 4.20V = 100%")
h.assertNear(chemistry.percent("LiPo", 3.30), 0,   0.1, "LiPo 3.30V = 0%")

-- LiPo curve points
h.assertNear(chemistry.percent("LiPo", 4.10), 90, 0.1, "LiPo 4.10V = 90%")
h.assertNear(chemistry.percent("LiPo", 3.82), 50, 0.1, "LiPo 3.82V = 50%")
h.assertNear(chemistry.percent("LiPo", 3.70), 10, 0.1, "LiPo 3.70V = 10%")

-- LiPo interpolation (between 4.10=90% and 4.00=80%; 4.05 should be ~85%)
h.assertNear(chemistry.percent("LiPo", 4.05), 85, 0.5, "LiPo 4.05V ~ 85%")

-- Clamps
h.assertNear(chemistry.percent("LiPo", 4.30), 100, 0.1, "LiPo 4.30V over -> 100%")
h.assertNear(chemistry.percent("LiPo", 3.00),   0, 0.1, "LiPo 3.00V under -> 0%")

-- LiHV
h.assertNear(chemistry.percent("LiHV", 4.35), 100, 0.1, "LiHV 4.35V = 100%")
h.assertNear(chemistry.percent("LiHV", 3.30),   0, 0.1, "LiHV 3.30V = 0%")
h.assertNear(chemistry.percent("LiHV", 3.97),  50, 0.1, "LiHV 3.97V = 50%")

-- Li-Ion
h.assertNear(chemistry.percent("Li-Ion", 4.20), 100, 0.1, "Li-Ion 4.20V = 100%")
h.assertNear(chemistry.percent("Li-Ion", 2.80),   0, 0.1, "Li-Ion 2.80V = 0%")
h.assertNear(chemistry.percent("Li-Ion", 3.82),  50, 0.1, "Li-Ion 3.82V = 50%")

-- Unknown chemistry returns nil
h.assertEqual(chemistry.percent("Unobtainium", 3.8), nil, "Unknown chemistry -> nil")

-- maxVoltage table exposed
h.assertNear(chemistry.maxVoltage.LiPo,    4.25, 0.001, "maxVoltage LiPo")
h.assertNear(chemistry.maxVoltage.LiHV,    4.40, 0.001, "maxVoltage LiHV")
h.assertNear(chemistry.maxVoltage["Li-Ion"], 4.25, 0.001, "maxVoltage Li-Ion")

print("--- chemistry tests done ---")
```

- [ ] **Step 2.7: Lancer, observer les échecs**

Run:
```powershell
lua tests/test_chemistry.lua
```

Expected : plusieurs FAIL (les courbes LiPo/LiHV/Li-Ion sont incomplètes et l'interpolation à 4.05V ne passe pas le seuil de tolérance).

- [ ] **Step 2.8: Compléter les courbes dans `chemistry.lua`**

Replace `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\chemistry.lua` content with :
```lua
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
```

- [ ] **Step 2.9: Tous les tests passent**

Run:
```powershell
lua tests/test_chemistry.lua
```

Expected : tous PASS, ligne finale `--- chemistry tests done ---`.

- [ ] **Step 2.10: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add scripts/battind/chemistry.lua tests/test_chemistry.lua tests/helpers.lua
git -C J:\_Dev\Perso\TestEthos commit -m "feat(chemistry): voltage-per-cell to percent interpolation for LiPo/LiHV/Li-Ion"
```

---

## Task 3: Module `cells.lua` (TDD)

**Files :**
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\test_cells.lua`
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\cells.lua`

- [ ] **Step 3.1: Écrire tests `cells.lua`**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\tests\test_cells.lua` :
```lua
package.path = "scripts/battind/?.lua;tests/?.lua;" .. package.path
local h = require("helpers")
local cells = require("cells")

local LIPO_MAX = 4.25

-- Need 3 samples before any detection
local s = cells.new()
h.assertEqual(cells.update(s, 12.6, LIPO_MAX), nil, "1 sample -> nil")
h.assertEqual(cells.update(s, 12.6, LIPO_MAX), nil, "2 samples -> nil")
h.assertEqual(cells.update(s, 12.6, LIPO_MAX),   3, "3 stable 12.6V -> 3S")

-- 4S detection
s = cells.new()
cells.update(s, 16.8, LIPO_MAX)
cells.update(s, 16.8, LIPO_MAX)
h.assertEqual(cells.update(s, 16.8, LIPO_MAX), 4, "3 stable 16.8V -> 4S")

-- 6S detection
s = cells.new()
cells.update(s, 25.2, LIPO_MAX)
cells.update(s, 25.2, LIPO_MAX)
h.assertEqual(cells.update(s, 25.2, LIPO_MAX), 6, "3 stable 25.2V -> 6S")

-- Borderline: 4.25V exactly = 1S (ceil at edge)
s = cells.new()
cells.update(s, 4.25, LIPO_MAX)
cells.update(s, 4.25, LIPO_MAX)
h.assertEqual(cells.update(s, 4.25, LIPO_MAX), 1, "3 stable 4.25V -> 1S")

-- 8.5V = 2S (ceil(8.5/4.25) = 2)
s = cells.new()
cells.update(s, 8.5, LIPO_MAX)
cells.update(s, 8.5, LIPO_MAX)
h.assertEqual(cells.update(s, 8.5, LIPO_MAX), 2, "3 stable 8.5V -> 2S")

-- Instability prevents detection
s = cells.new()
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.0, LIPO_MAX)
h.assertEqual(cells.update(s, 12.7, LIPO_MAX), nil, "unstable -> nil")

-- Recovery: now feed 3 stable samples
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.65, LIPO_MAX)
h.assertEqual(cells.update(s, 12.6, LIPO_MAX), 3, "after instability, stable -> 3S")

-- Zero voltage resets the sample buffer
s = cells.new()
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 0,    LIPO_MAX)
h.assertEqual(cells.update(s, 12.6, LIPO_MAX), nil, "after zero reset, 1 sample -> nil")

-- nil voltage also resets
s = cells.new()
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, nil,  LIPO_MAX)
h.assertEqual(cells.update(s, 12.6, LIPO_MAX), nil, "after nil reset, 1 sample -> nil")

-- Pack change: stable 3S then stable 1S -> redetect
s = cells.new()
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)  -- now 3S
cells.update(s, 4.2,  LIPO_MAX)
cells.update(s, 4.2,  LIPO_MAX)
h.assertEqual(cells.update(s, 4.2, LIPO_MAX), 1, "pack swap 3S->1S detected")

-- Small voltage drift does NOT trigger redetection (sag is normal)
s = cells.new()
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)  -- 3S detected
cells.update(s, 11.7, LIPO_MAX)
cells.update(s, 11.7, LIPO_MAX)
h.assertEqual(cells.update(s, 11.7, LIPO_MAX), 3, "voltage sag keeps detected 3S")

-- Reset clears everything
s = cells.new()
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)
cells.update(s, 12.6, LIPO_MAX)  -- 3S
cells.reset(s)
h.assertEqual(cells.update(s, 12.6, LIPO_MAX), nil, "after reset, 1 sample -> nil")

print("--- cells tests done ---")
```

- [ ] **Step 3.2: Lancer, vérifier l'échec**

Run:
```powershell
cd J:\_Dev\Perso\TestEthos
lua tests/test_cells.lua
```

Expected : `module 'cells' not found`.

- [ ] **Step 3.3: Implémenter `cells.lua`**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\cells.lua` :
```lua
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
  return (hi - lo) <= STABILITY_THRESHOLD_V, (lo + hi) / 2
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

  local stable, mid = windowStable(state)
  if not stable then
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
```

- [ ] **Step 3.4: Tous les tests passent**

Run:
```powershell
lua tests/test_cells.lua
```

Expected : tous PASS, ligne finale `--- cells tests done ---`.

- [ ] **Step 3.5: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add scripts/battind/cells.lua tests/test_cells.lua
git -C J:\_Dev\Perso\TestEthos commit -m "feat(cells): auto-detect cell count from stable voltage window with pack-swap detection"
```

---

## Task 4: Squelette widget `main.lua` (registration + config UI)

**Files :**
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua`

À ce stade, on a juste le widget qui s'enregistre dans Ethos, expose un formulaire de config, et persiste les choix. Pas encore de lecture télémétrie ni d'audio. C'est testé manuellement dans le simulateur Ethos.

- [ ] **Step 4.1: Écrire `main.lua` v1 (registration + config + persistance)**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua` :
```lua
local chemistry = assert(loadfile("/scripts/battind/chemistry.lua"))()
local cells     = assert(loadfile("/scripts/battind/cells.lua"))()

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
    cellChoice   = 0,         -- 0 = Auto, else fixed count
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
    key       = "battind",
    name      = "Battery Indicator",
    create    = create,
    configure = configure,
    read      = read,
    write     = write,
    wakeup    = wakeup,
    paint     = paint,
    title     = false,
    persistent= false,
  })
end

return { init = init }
```

- [ ] **Step 4.2: Test manuel — installation dans le simulateur Ethos Suite**

Procédure :
1. Lancer Ethos Suite sur PC.
2. Ouvrir le simulateur, sélectionner profil X18.
3. Localiser le dossier SD virtuel du simulateur (typiquement `%LOCALAPPDATA%\FrSky\Ethos\<radio>\` ou similaire — apparaît dans les logs au démarrage du simulateur).
4. Copier `scripts/battind/` (avec ses 3 fichiers `.lua`) dans le dossier `scripts/` de la SD virtuelle.
5. Redémarrer le simulateur.
6. Sur l'écran principal de la radio simulée, longue-presse une zone vide → "Add widget" → vérifier que "Battery Indicator" apparaît dans la liste.
7. L'ajouter.
8. Entrer dans sa config → vérifier les 4 champs (Voltage source, Cell count, Battery chemistry, Audio period) avec les bonnes valeurs par défaut.
9. Modifier la chimie en LiHV, sortir, ré-entrer en config → vérifier que LiHV est conservé.

Expected : tout l'enchaînement passe. Le widget affiche juste "BattInd (config only)" pour l'instant.

**Si l'API diverge (par exemple `system.registerWidget` requiert un champ supplémentaire ou `form.addChoiceField` a une signature différente sur Ethos 26)** : consulter la doc Ethos 26 dans Ethos Suite (menu Help → Lua API) et ajuster les signatures en gardant la structure. Ne pas changer la logique métier.

- [ ] **Step 4.3: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add scripts/battind/main.lua
git -C J:\_Dev\Perso\TestEthos commit -m "feat(widget): register Battery Indicator widget with config UI and persistence"
```

---

## Task 5: Boucle `wakeup` (lecture télémétrie → cellules → %)

**Files :**
- Modify: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua` (function `wakeup`)

- [ ] **Step 5.1: Remplacer la fonction `wakeup` dans `main.lua`**

Replace in `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua`, the line
```lua
local function wakeup(widget)
  -- (filled in Task 5)
end
```
with :
```lua
local function wakeup(widget)
  -- Read voltage source
  local v = nil
  if widget.source then
    v = widget.source:value()
  end
  widget.voltage = v

  -- Resolve cell count: manual override or auto-detected
  local maxV = chemistry.maxVoltage[widget.chemistry] or 4.25
  if widget.cellChoice and widget.cellChoice > 0 then
    widget.cellCount = widget.cellChoice
  else
    widget.cellCount = cells.update(widget.detector, v, maxV)
  end

  -- Compute percentage
  if v and v > 0 and widget.cellCount then
    local vPerCell = v / widget.cellCount
    widget.pct = chemistry.percent(widget.chemistry, vPerCell)
  else
    widget.pct = nil
  end

  -- (audio in Task 7)

  lcd.invalidate()
end
```

- [ ] **Step 5.2: Améliorer `paint` pour afficher les valeurs lues**

Replace in `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua`, the function `paint(widget)` body with :
```lua
local function paint(widget)
  local w, h = lcd.getWindowSize()
  lcd.color(lcd.RGB(255, 255, 255))

  local function fmt(v, suffix)
    if v == nil then return "--" .. (suffix or "") end
    return string.format("%.2f%s", v, suffix or "")
  end

  local vStr   = fmt(widget.voltage, " V")
  local pctStr = widget.pct and string.format("%d%%", math.floor(widget.pct + 0.5)) or "-- %"
  local cellStr= widget.cellCount and (widget.cellCount .. "S") or "--S"

  lcd.drawText(4,   4, pctStr,  LEFT)
  lcd.drawText(4,  30, vStr,    LEFT)
  lcd.drawText(4,  56, cellStr, LEFT)
end
```

- [ ] **Step 5.3: Test manuel dans simulateur**

Procédure :
1. Copier le `main.lua` modifié dans la SD virtuelle, redémarrer le simulateur.
2. Dans le simulateur Ethos, créer une source télémétrie de test : menu Model → Telemetry → Add → Custom sensor. Nom = "TestV", unit = V, valeur initiale = 12.6.
3. Dans la config du widget : Voltage source = TestV, Cell count = Auto, Chemistry = LiPo, Audio period = Off.
4. Sortir de la config.
5. Vérifier l'affichage : `100%`, `12.60 V`, `3S`.
6. Modifier la valeur de TestV à 11.10 → l'écran doit afficher ~ `48%` (3.70V/cell ≈ 10%, mais 11.10/3 = 3.70V → 10% — voir note ci-dessous), `11.10 V`, `3S`.

   *Note :* 11.10 V / 3 = 3.70 V/cell, qui sur la courbe LiPo = 10%. Pour avoir ~50%, utiliser 11.46 V (3.82 V/cell). Adapter la valeur de test selon la courbe LiPo du spec.

7. Modifier TestV à 0 → affichage `-- %`, `-- V` (puisque 0 est traité comme "pas de télémétrie").
8. Reposer TestV à 12.6 → après 3 tours de wakeup, ré-affiche 100%, 3S.

Expected : tous les cas se comportent comme décrit.

- [ ] **Step 5.4: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add scripts/battind/main.lua
git -C J:\_Dev\Perso\TestEthos commit -m "feat(widget): wakeup loop reads telemetry and computes cell count and percent"
```

---

## Task 6: Layout adaptatif + jauge

**Files :**
- Modify: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua` (function `paint`)

- [ ] **Step 6.1: Remplacer la fonction `paint` par la version adaptative**

Replace the entire `paint` function body in `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua` with :
```lua
local COLOR_BG    = lcd.RGB(0,   0,   0)
local COLOR_FG    = lcd.RGB(255, 255, 255)
local COLOR_DIM   = lcd.RGB(120, 120, 120)
local COLOR_GREEN = lcd.RGB( 60, 200,  60)
local COLOR_AMBER = lcd.RGB(230, 170,   0)
local COLOR_RED   = lcd.RGB(220,  40,  40)

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
    lcd.font(FONT_L)
    lcd.drawText(4, 2, pctStr, LEFT)
    lcd.font(FONT_S)
    local rightStr = cellStr .. "  " .. vStr
    lcd.drawText(w - 4, 6, rightStr, RIGHT)

    -- gauge: full width minus 8px margin, 12px high near bottom
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
    lcd.font(FONT_XL)
    lcd.drawText(8, 4, pctStr, LEFT)
    lcd.font(FONT_L)
    lcd.drawText(w - 8, 4, vStr, RIGHT)
    lcd.font(FONT_M)
    lcd.drawText(w - 8, 4 + 32, cellStr, RIGHT)

    -- gauge: full width minus 16px margin, 20px high near bottom
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
```

**Note sur les constantes de font et d'alignement :** `FONT_S`, `FONT_M`, `FONT_L`, `FONT_XL`, `LEFT`, `RIGHT` sont des globales Ethos. Si une constante n'existe pas dans Ethos 26 (les noms ont parfois évolué), remplacer par le nom équivalent (par exemple `FONT_STD`, `FONT_BOLD`, `BOLD`, etc.) en consultant la doc API du simulateur.

- [ ] **Step 6.2: Test manuel — layout X18**

Procédure :
1. Copier `main.lua` dans la SD virtuelle, profil X18, redémarrer le simulateur.
2. Avec TestV à 12.6 V (3S, 100%) → grand `100%` à gauche, `12.60 V` à droite, `3S` sous la tension, jauge **verte** pleine en bas.
3. Avec TestV à 11.46 V (~50%) → `~50%`, jauge **ambre** à moitié.
4. Avec TestV à 10.5 V (~5–10%) → jauge **rouge** très courte.
5. Vérifier qu'aucun texte n'est tronqué et que la jauge ne déborde pas.

- [ ] **Step 6.3: Test manuel — layout X-Lite S**

Procédure :
1. Dans Ethos Suite, changer le profil simulateur pour X-Lite S (Settings → Simulator → Radio).
2. Relancer.
3. Vérifier que le widget bascule en layout compact (texte plus petit, sur une ligne en haut).
4. Vérifier les mêmes états (100%, 50%, 10%) → couleurs et texte cohérents.

**Si la résolution exacte fait passer le simulateur juste au-dessus ou en-dessous du seuil de 320 px** : ajuster le seuil dans le code (`compact = (w < 320)`) jusqu'à ce que le bon layout soit choisi.

- [ ] **Step 6.4: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add scripts/battind/main.lua
git -C J:\_Dev\Perso\TestEthos commit -m "feat(widget): adaptive layout (large/compact) with colored capacity gauge"
```

---

## Task 7: Annonce audio périodique

**Files :**
- Modify: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua` (function `wakeup`)

- [ ] **Step 7.1: Ajouter la logique audio dans `wakeup`**

Replace the entire `wakeup` function in `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\scripts\battind\main.lua` with :
```lua
local function wakeup(widget)
  -- Read voltage source
  local v = nil
  if widget.source then
    v = widget.source:value()
  end
  widget.voltage = v

  -- Resolve cell count: manual override or auto-detected
  local maxV = chemistry.maxVoltage[widget.chemistry] or 4.25
  if widget.cellChoice and widget.cellChoice > 0 then
    widget.cellCount = widget.cellChoice
  else
    widget.cellCount = cells.update(widget.detector, v, maxV)
  end

  -- Compute percentage
  if v and v > 0 and widget.cellCount then
    local vPerCell = v / widget.cellCount
    widget.pct = chemistry.percent(widget.chemistry, vPerCell)
  else
    widget.pct = nil
  end

  -- Audio readout: skip if disabled, no telemetry, no detection, or before first interval since boot
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
```

- [ ] **Step 7.2: Test manuel — annonce 30s**

Procédure :
1. Copier `main.lua`, redémarrer le simulateur (profil X18).
2. Config widget : Voltage source = TestV, Cell count = Auto, Chemistry = LiPo, Audio period = **30 s**.
3. TestV à 12.6 V.
4. Attendre 30 s → la radio annonce "one hundred percent".
5. Attendre 30 s de plus → seconde annonce.
6. Changer TestV à 11.46 V → après la prochaine annonce, la valeur annoncée doit suivre (~50%).

Expected : annonces régulières, valeur cohérente avec l'affichage.

- [ ] **Step 7.3: Test manuel — Audio Off**

Procédure :
1. Reconfigurer Audio period = Off.
2. Sortir, attendre 2 minutes → aucune annonce.

- [ ] **Step 7.4: Test manuel — pas de télémétrie**

Procédure :
1. Audio period = 30 s, Voltage source vide (ou TestV à 0).
2. Attendre 1 minute → aucune annonce (puisque `pct` est nil).

- [ ] **Step 7.5: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add scripts/battind/main.lua
git -C J:\_Dev\Perso\TestEthos commit -m "feat(widget): periodic audio readout of battery percentage with first-announce delay"
```

---

## Task 8: README

**Files :**
- Create: `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\README.md`

- [ ] **Step 8.1: Écrire le README**

Create `J:\_Dev\Perso\TestEthos\EthOS_Battery_Gauge\README.md` :
```markdown
# BattInd — Battery Indicator Widget for FrSky Ethos

Widget Ethos affichant le niveau d'une batterie à partir d'une source télémétrie de tension, avec annonce audio périodique configurable.

Compatible Ethos 26+. Testé sur Tandem X18/X18S et Twin X-Lite S.

## Installation

1. Copier le dossier `scripts/battind/` sur la carte SD de la radio, dans `/scripts/`.
2. Démarrer la radio.
3. Sur un écran principal, longue-presse une zone vide → **Add widget** → **Battery Indicator**.

## Configuration

Dans la config du widget :

| Champ                | Description                                                     |
|----------------------|-----------------------------------------------------------------|
| Voltage source       | Capteur télémétrie de tension (RxBt, A1, VFR, sensor custom du module multiprotocole, etc.) |
| Cell count           | `Auto` (détection automatique) ou nombre fixe (1S à 12S)        |
| Battery chemistry    | `LiPo` (3.30–4.20 V/cell) / `LiHV` (3.30–4.35 V/cell) / `Li-Ion` (2.80–4.20 V/cell) |
| Audio period         | Intervalle entre annonces vocales (Off / 5 / 10 / 15 / 30 / 60 / 120 s) — défaut **30 s** |

### Détection automatique du nombre de cellules

En `Auto`, le widget attend 3 lectures consécutives de tension avec une variation < 0.1 V (≈ 1 s), puis calcule `ceil(V_moyen / V_max_par_cellule)`. Le `V_max` dépend de la chimie choisie (4.25 V pour LiPo/Li-Ion, 4.40 V pour LiHV).

Une fois le pack détecté, un changement de pack (tension par cellule différente de > 0.5 V) déclenche une re-détection automatique.

### Estimation du %

Le widget utilise une table d'interpolation par chimie (11 points), bien plus juste qu'une rampe linéaire entre tension min et max. À 50 % d'une LiPo, on est à 3.82 V/cellule, pas à mi-chemin entre 3.30 et 4.20.

## Affichage

- **Grand écran (≥ 320 px, X18) :** `87%` en gros à gauche, `xS` et tension à droite, jauge horizontale colorée en bas.
- **Écran compact (X-Lite S) :** tout sur une ligne en haut, jauge en bas.

Couleurs jauge : vert ≥ 50 %, ambre 20–49 %, rouge < 20 %.

## Dépannage

| Symptôme | Cause probable | Remède |
|---|---|---|
| Affichage `-- %` en permanence | Source pas configurée ou pas de signal télémétrie | Vérifier la source dans la config, et que le récepteur est lié |
| Audio ne se déclenche jamais | Audio period = Off, ou pas de télémétrie | Mettre une période > 0 et vérifier la source |
| Cellules `--S` en mode Auto | Tension instable (vol en cours, sag) | Brancher le pack au repos pour la première détection |
| Cellules détectées fausses | Pack très déchargé au branchement | Forcer manuellement le nombre de cellules en config |

## Tests unitaires (développement)

```powershell
cd J:\_Dev\Perso\TestEthos
lua tests/test_chemistry.lua
lua tests/test_cells.lua
```

Nécessite Lua 5.4 (ou 5.3) dans le PATH. Sur Windows : `winget install -e --id DEVCOM.Lua`.

## Structure

```
scripts/battind/
├── main.lua        Widget glue Ethos
├── chemistry.lua   Tables de décharge + interpolation V/cell -> %
└── cells.lua       Détection automatique du nombre de cellules
```
```

- [ ] **Step 8.2: Commit**

Run:
```powershell
git -C J:\_Dev\Perso\TestEthos add README.md
git -C J:\_Dev\Perso\TestEthos commit -m "docs: add README with install, config, troubleshooting"
```

---

## Récapitulatif des commits attendus

1. `chore: bootstrap project structure with spec and plan`
2. `feat(chemistry): voltage-per-cell to percent interpolation for LiPo/LiHV/Li-Ion`
3. `feat(cells): auto-detect cell count from stable voltage window with pack-swap detection`
4. `feat(widget): register Battery Indicator widget with config UI and persistence`
5. `feat(widget): wakeup loop reads telemetry and computes cell count and percent`
6. `feat(widget): adaptive layout (large/compact) with colored capacity gauge`
7. `feat(widget): periodic audio readout of battery percentage with first-announce delay`
8. `docs: add README with install, config, troubleshooting`
