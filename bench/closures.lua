-- closures and upvalues
local function counter() local c = 0 return function() c = c + 1 return c end end
local s = 0
for i = 1, 1500000 do
  local f = counter()
  for j = 1, 10 do s = s + f() end
end
assert(s > 0)
