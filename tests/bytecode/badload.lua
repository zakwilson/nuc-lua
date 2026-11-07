-- Prints what loading each corruption of a dump gives: every truncation, and
-- every byte set to 0, 0x80 and 0xff, so two implementations can be compared.
-- Run it under a memory limit: a corrupted size may ask for gigabytes.
local src = [[
local up = {}
local function f(a, b, ...)
  local s = "a long string constant, past the forty bytes of a short one"
  local t <const> = 42
  up[a] = {b, 1.5, -7, true, false, nil, "k", s, 2^60}
  local va = {...}
  return function() return up, t, va end
end
return f
]]
local d = string.dump(assert(load(src, "@bad.lua")))
local function try(tag, s, name)
  local ok, g, e = pcall(load, s, name, "b")
  print(tag, ok and (g and "loads" or e) or "error " .. tostring(g))
end
try("whole", d, "=c")
try("named @", d, "@file.luac")
try("unnamed", d)
try("named by its bytes", d:sub(1, 20), d)  -- a name that starts with the signature
for n = 0, #d - 1 do try("trunc " .. n, d:sub(1, n), "=c") end
for i = 1, #d do
  for _, v in ipairs{0, 0x80, 0xff} do
    try("byte " .. i .. " " .. v, d:sub(1, i - 1) .. string.char(v) .. d:sub(i + 1), "=c")
  end
end
