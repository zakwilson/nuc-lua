-- Run from a dump made by the other implementation; prints the same either way.
local t = {}
for i = 1, 10 do t[#t + 1] = i * i end
local function fib(n) if n < 2 then return n end return fib(n - 1) + fib(n - 2) end
local s = table.concat(t, ",")
local mt = {__index = function(_, k) return k .. "!" end, __add = function(a, b) return 42 end}
local o = setmetatable({}, mt)
local co = coroutine.wrap(function(a) local b = coroutine.yield(a + 1); return b * 2 end)
print(s, fib(20), o.x, o + 1, co(1), co(5), string.format("%5.2f|%q", math.pi, "a\nb"),
      ("hello"):gsub("l+", "L"), 7 // 2, 7.0 // 2, 3 & 5, 1 << 62, -0.0, 2^63, "x" .. 1)
goto done
print("skipped")
::done::
do local x <close> = setmetatable({}, {__close = function() print("closed") end}) end
print(select("#", ...), ...)
