-- Loads each binary chunk named in arg without running it.
for i = 1, #arg do
  local f, err = loadfile(arg[i], "b")
  if not f then io.stderr:write(arg[i], ": ", err, "\n"); os.exit(1) end
end
