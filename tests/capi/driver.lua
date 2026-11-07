-- The C API matrix driver (PROMPT.md §7.3): one script for every cell.
-- `lua driver.lua DIR` loads capi.so from DIR and runs its transcript.
package.cpath = arg[1] .. "/?.so"
local capi = require "capi"
capi.run()
