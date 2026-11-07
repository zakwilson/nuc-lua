-- Prints the message each malformed chunk gets from the compiler, so two
-- implementations' outputs can be compared.
local chunks = {
  "local x <const> = 1; x = 2",
  "local x <close> = 1; local y <close> = 2; x = 3",
  "goto nowhere",
  "do ::a:: end goto a",
  "::a:: ::a::",
  "break",
  "local x <foo> = 1",
  "global x; global<const> y; y = 1",
  "global none; z = 1",
  "return " .. string.rep("(", 300) .. "1" .. string.rep(")", 300),
  "local " .. string.rep("a,", 250) .. "a",
  "local t = {" .. string.rep("{", 300) .. string.rep("}", 300) .. "}",
  "f(" .. string.rep("1,", 300) .. "1)",
  "local function f(...) return function() return ... end end",
  "for i = 1 do end",
  "x = 1 = 2",
  "local a = {...}; local function g() return ... end",
  "return 1 + {}",
  "local x = 1 // 0",
  string.rep("local x; ", 210),
}
for i, c in ipairs(chunks) do
  local f, msg = load(c, "=chunk" .. i)
  print(i, f and "ok" or msg)
end
