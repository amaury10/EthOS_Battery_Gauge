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
