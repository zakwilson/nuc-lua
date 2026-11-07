-- Writes sources that drive the code generator past its common paths into
-- directory arg[1]: LOADKX, SETLIST's extra argument, absolute line info,
-- folding edge cases and every operator form.
local dir = arg[1]
local function emit(name, s)
  local f = assert(io.open(dir .. "/" .. name .. ".lua", "w"))
  f:write(s)
  f:close()
end

-- More constants than Bx holds, so the last ones load with LOADKX.
local t = {"local t = {}"}
for i = 1, 140000 do t[#t + 1] = ("t[%d] = 'k%d' .. %d.5"):format(i % 50, i, i) end
emit("manyk", table.concat(t, "\n"))

-- Constructors past MAXARG_vC items, and big hash parts.
t = {"return {"}
for i = 1, 3000 do t[#t + 1] = i .. "," end
for i = 1, 600 do t[#t + 1] = ("h%d = %d,"):format(i, i) end
t[#t + 1] = "...}"
emit("bigtable", table.concat(t, "\n"))

-- Lines far apart, and many instructions on one line.
t = {}
for i = 1, 40 do
  t[#t + 1] = ("local a%d = %d"):format(i, i) .. string.rep("\n", (i * 37) % 300)
end
t[#t + 1] = "local x = 0 " .. string.rep("x = x + 1 ", 400)
emit("lines", table.concat(t, "\n"))

-- Folding: some cases fold, the risky ones (NaN, -0.0, errors) must not.
emit("fold", [[
local x, y = ...
local a = {-0.0, 0/0, 1//0, 1%0, 3 & 1.5, 2^53, 1e308*10, - -9223372036854775807,
  ~5, 1 << 63, 1 >> 64, 7 // 2, 7.0 // 2, -7 % 3, 2^-1074, 3 | 4, "a".."b",
  -(-128), 1 - 1, 0.0 * -1, math.huge, -math.huge, 0x7fffffffffffffff + 1}
local b = {x + 1, 1 + x, x - 1, x - (-128), x - 300, x * 2.0, 2 * x, x / 3, x // 3,
  x % 3, x ^ 2, x + 1.5, x + 1000, 1000 - x, x * 1e100, x & 1, 1 & x, x | y, x ~ 0xff, x << 3, 3 << x, x >> -1, x >> 1,
  x << -2, -x, ~x, #x, not x, x .. y .. "z" .. 1 .. 2.5}
local c = {x < 3, x <= 3.0, x > 127, x >= -128, 3 < x, 3.5 < x, x == 1, x == 1.0,
  x == "s", x ~= nil, x == true, 1 == x, x < y, x >= y, x == y, x ~= y}
local d = (x and y) or (not x and 1) or (x == y and nil) or false
if x and not y or (x or y) and (x == 1 or y ~= 2) then d = 1 elseif not (x < y) then d = 2 end
while x and y do x = x - 1 if x < 0 then break end end
repeat local z = x until z or y
for i = 10, 1, -2 do d = i end
for i = 1.0, 3 do d = i end
for k, v in pairs(a) do d = k end
goto skip
d = 0
::skip::
return a, b, c, d
]])

-- Variables of every kind: upvalues, <const>, globals, varargs, methods.
emit("vars", [[
global print, string, table, select
local K <const> = 42
local S <const> = "const"
local F <const> = 1.5
local up = {}
local function f(...)
  local a, b = ...
  local t = {...}
  local n = select('#', ...)
  up.x = K + a
  up[S] = F
  up[1] = up[2]
  up.method_with_a_name_much_longer_than_forty_characters_xxxxxx = f
  up:method_with_a_name_much_longer_than_forty_characters_xxxxxx(1)
  return string.format("%d", n), ..., up:m(t)
end
local function g(...)
  local t <close> = nil
  return (...), select(2, ...) and 1
end
local function h(...t)
  t[1] = 2
  return t.n, t[1], #t
end
local function v(...va) return va end
local function r(...t) local k = 2 return t[1], t.n, t[k] end
global x
x = 1
global y, z = 1, 2
global function gf() return y end
global<const> *
return f, g, h, v
]])
