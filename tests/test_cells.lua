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
