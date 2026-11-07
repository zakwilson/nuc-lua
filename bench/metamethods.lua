-- metamethod dispatch
local V = {}
V.__index = V
V.__add = function(a, b) return setmetatable({x = a.x + b.x}, V) end
V.__eq = function(a, b) return a.x == b.x end
V.__len = function(a) return a.x end
local p = setmetatable({}, {__index = function(t, k) return k end})
local acc = setmetatable({x = 0}, V)
local one = setmetatable({x = 1}, V)
local n = 0
for i = 1, 2000000 do
  acc = acc + one
  if acc == one then n = n + 1 end
  n = n + #acc % 2 + p[1]
end
assert(n > 0)
