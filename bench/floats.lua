-- floating-point loops
local s = 0.0
for i = 1, 3e7 do s = s + (i * 0.5) / (i + 1.0) end
assert(s > 0)
