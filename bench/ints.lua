local s = 0
for i = 1, 4e7 do s = s + (i-1) + (i-2) end
assert(s > 0)
