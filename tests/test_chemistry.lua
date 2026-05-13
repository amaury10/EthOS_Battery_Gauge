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
