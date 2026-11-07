-- pattern matching
local text = string.rep("the quick brown fox jumps over 12 lazy dogs; ", 2000)
local n = 0
for r = 1, 120 do
  for w in text:gmatch("%a+") do n = n + 1 end
  n = n + select(2, text:gsub("%d+", "N"))
  n = n + (text:find("dogs; the", 1, true) or 0)
end
assert(n > 0)
