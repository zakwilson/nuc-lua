-- table reads and writes, array and hash parts
local t, h = {}, {}
for r = 1, 20 do
  for i = 1, 200000 do t[i] = i + r end
  for i = 1, 200000 do h["k" .. (i % 1000)] = t[i] end
end
local s = 0
for i = 1, #t do s = s + t[i] end
assert(s > 0 and h.k1)
