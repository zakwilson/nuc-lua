-- garbage collector churn: short-lived tables and strings, and a live set
local live = {}
for i = 1, 3000000 do
  local t = {i, tostring(i % 100), {}}
  if i % 100 == 0 then live[(i // 100) % 5000 + 1] = t end
end
assert(#live == 5000)
