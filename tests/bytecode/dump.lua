-- Writes string.dump(loadfile(arg[1]), strip) to arg[2]; strip is arg[3] == "1".
local f = assert(loadfile(arg[1]))
local out = assert(io.open(arg[2], "wb"))
out:write(string.dump(f, arg[3] == "1"))
out:close()
