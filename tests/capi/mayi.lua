-- mayi's behaviour (PROMPT.md §7.3). `lua mayi.lua DIR idle|ready`; stdin is a
-- pipe holding no data (idle) or some (ready).
package.cpath = arg[1] .. "/?.so"
local m = require "mayi"
print(type(m), type(m.mayi))
if arg[2] == "idle" then
  print(m.mayi(0.01), m.mayi("0.01"), m.mayi(), m.mayi("x"))
else
  print(m.mayi(0.2))
end
