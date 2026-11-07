-- string building
local n = 0
for r = 1, 40 do
  local parts = {}
  for i = 1, 20000 do parts[#parts + 1] = tostring(i) .. "," end
  local s = table.concat(parts)
  local u = ""
  for i = 1, 2000 do u = u .. "x" end
  n = n + #s + #u
end
assert(n > 0)
