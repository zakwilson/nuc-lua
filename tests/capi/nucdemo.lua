-- libs/nucdemo's behaviour (PROMPT.md §6.5), the same in every host.
-- `lua nucdemo.lua DIR` loads nucdemo.so, and mayi.so beside it, from DIR.
package.cpath = arg[1] .. "/?.so"
local d = require "nucdemo"
local mayi = require "mayi"  -- a second Nucleus library in the same process
print("loaded", type(d), type(mayi.mayi))

-- a userdata owning a Vector: methods, __len, __tostring, __gc, __close
local s = d.stats(4, 1, 3)
s:add(2):add(5)
print("stats", #s, s:mean(), s:median(), string.format("%.4f", s:stddev()), tostring(s))
print("empty", pcall(d.stats().mean, d.stats()))
print("bad arg", pcall(s.add, s, "x"))
do
  local t <close> = d.stats(1, 2)
  print("in scope", tostring(t))
  s = t
end
print("after close", tostring(s), pcall(s.mean, s))
print("not stats", pcall(s.mean, {}))
for i = 1, 200 do d.stats(i, i + 1) end  -- left to __gc
collectgarbage()

-- a C closure over upvalues
local c = d.counter(10, 5)
print("counter", c(), c(), c(), d.counter()())

-- a HashMap anchored in a userdata
local counts, order = d.words("the cat and the hat; THE end, the cat")
local parts = {}
for i, w in ipairs(order) do parts[i] = w .. "=" .. counts[w] end
print("words", table.concat(parts, " "))

-- luaL_Buffer
print("join", d.join({1, "two", 3.5, true, setmetatable({}, {__tostring = function() return "obj" end})}, ", "))
print("join empty", "[" .. d.join({}) .. "]", d.join({"a", "b"}))
print("join long", #d.join(setmetatable({}, {__len = function() return 3000 end, __index = function(_, i) return "xy" end}), "-"))

-- registry references and callbacks; errors in callbacks come back as values
local log = {}
local h1 = d.on(function(a, b) log[#log + 1] = "h1:" .. a .. b end)
local h2 = d.on(function(a) error("h2 failed on " .. a, 0) end)
local h3 = d.on(function(a, b) log[#log + 1] = "h3:" .. (a + b) end)
local n, errs = d.emit(1, 2)
print("emit", n, #errs, errs[1], table.concat(log, ","))
print("off", d.off(h2), d.off(h2))
n, errs = d.emit(3, 4)
print("emit", n, #errs, table.concat(log, ","))
d.off(h1) d.off(h3)
local n0, e0 = d.emit()
print("emit none", n0, #e0)

-- a Nucleus Result raised as a Lua error
print("parse", d.parse(" 42 "), d.parse("-9223372036854775808"), d.parse("+7"))
print("parse bad", pcall(d.parse, "4x2"))
print("parse big", pcall(d.parse, "9223372036854775808"))
print("parse empty", pcall(d.parse, "  "))

-- lua_callk: f may yield inside each()
local co = coroutine.wrap(function()
  return d.each({"a", "b", "c"}, function(i, v)
    local got = coroutine.yield(i .. v)
    print("each resumed", i, got)
  end)
end)
print("each yield", co())
print("each yield", co("x"))
print("each yield", co("y"))
print("each done", co("z"))
print("each plain", d.each({10, 20}, function(i, v) end))
print("each error", pcall(d.each, {1}, function() error("stop", 0) end))

-- lua_pcallk: f may yield inside try()
co = coroutine.wrap(function()
  return d.try(function(a)
    local b = coroutine.yield("paused " .. a)
    if b == "boom" then error("boom!", 0) end
    return a, b
  end, "A")
end)
print("try", co())
print("try", co("B"))
co = coroutine.wrap(function()
  return d.try(function() coroutine.yield(1) error({code = 7}) end)
end)
co()
local ok, e = co()
print("try error", ok, type(e), e.code)
print("try plain", d.try(function(...) return ... end, 1, 2, 3))
print("try nested", d.try(d.try, error, "x"))

-- an error raised in Nucleus, through Lua, caught by Nucleus, in a coroutine
co = coroutine.create(function()
  return d.try(function() return d.parse("nope") end)
end)
local ok1, ok2, msg = coroutine.resume(co)
print("resume", ok1, ok2, (msg:gsub("^.*/", "")))  -- the script's path varies
print("done")
