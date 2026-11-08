#!/usr/bin/env bash
# Prints ISSUES.md's line-count table: per subsystem, the stock C files against
# their Nucleus ports, in code lines (no blank or comment-only lines) and in
# non-blank characters outside comments, since a Lisp line holds more than a C one.
set -eu
cd "$(dirname "$0")/.."
C=reference/build/src
T=build/suite/ltests

# Code lines of C files: strips /* */ and // comments, then counts non-blank lines.
ccount() {
  cat "$@" | awk '
    { line = $0; out = ""
      while (length(line) > 0) {
        if (inc) { i = index(line, "*/"); if (!i) { line = ""; break } line = substr(line, i + 2); inc = 0 }
        else {
          a = index(line, "/*"); b = index(line, "//")
          if (b && (!a || b < a)) { out = out substr(line, 1, b - 1); line = ""; break }
          if (!a) { out = out line; line = ""; break }
          out = out substr(line, 1, a - 1); line = substr(line, a + 2); inc = 1
        }
      }
      if (out ~ /[^ \t]/) n++; gsub(/[ \t]/, "", out); ch += length(out) }
    END { print n + 0, ch + 0 }'
}
# The same for Nucleus: a comment runs from a ; outside a string to the line's end.
ncount() {
  cat "$@" | awk '
    { out = ""; ins = 0
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (ins) { out = out c; if (c == "\\") { i++; out = out substr($0, i, 1) } else if (c == "\"") ins = 0 }
        else if (c == "\\") { out = out c substr($0, i + 1, 1); i++ }
        else if (c == ";") break
        else { out = out c; if (c == "\"") ins = 1 }
      }
      if (out ~ /[^ \t]/) n++; gsub(/[ \t]/, "", out); ch += length(out) }
    END { print n + 0, ch + 0 }'
}

row() { # name "c files" "nucleus files"
  local c cc n nc
  read -r c cc < <(ccount $2); read -r n nc < <(ncount $3)
  printf '| %s | %d | %d | %.2f | %d | %d | %.2f |\n' "$1" "$c" "$n" "$(echo "$n / $c" | bc -l)" \
    "$cc" "$nc" "$(echo "$nc / $cc" | bc -l)"
  TC=$((TC + c)); TN=$((TN + n)); TCC=$((TCC + cc)); TNC=$((TNC + nc))
}
TC=0; TN=0; TCC=0; TNC=0
S=src/lua
echo "| Subsystem | C lines | Nucleus lines | Ratio | C chars | Nucleus chars | Ratio |"
echo "|---|---|---|---|---|---|---|"
row "Object model (lctype, lzio, lmem, lobject, lstring, lfunc, ltm, ltable)" \
  "$(printf "$C/%s.c " lctype lzio lmem lobject lstring lfunc ltm ltable)" \
  "$(printf "$S/%s.nuc " ctype zio mem object string func tm table)"
row "Compiler (lopcodes, llex, lcode, lparser, ldump, lundump)" \
  "$(printf "$C/%s.c " lopcodes llex lcode lparser ldump lundump)" \
  "$(printf "$S/%s.nuc " opcodes lex code parser dump undump)"
row "Execution state (lstate, ldebug, ldo, lapi)" \
  "$(printf "$C/%s.c " lstate ldebug ldo lapi)" \
  "$(printf "$S/%s.nuc " state debug do api)"
row "Collector (lgc)" "$C/lgc.c" "$S/gc.nuc"
row "VM (lvm)" "$C/lvm.c" "$S/vm.nuc"
row "Auxiliary library and init (lauxlib, linit)" "$C/lauxlib.c $C/linit.c" "$S/aux.nuc $S/init.nuc"
row "Standard libraries (10)" \
  "$(printf "$C/%s.c " lbaselib lcorolib ldblib liolib lmathlib loadlib loslib lstrlib ltablib lutf8lib)" \
  "$(printf "$S/%s.nuc " baselib corolib dblib iolib mathlib loadlib oslib strlib tablib utf8lib)"
row "Hosts (lua.c, luac.c)" "$C/lua.c $C/luac.c" "src/main.nuc src/luac.nuc"
row "Internal headers' macros and limits (l*.h but the public four)" \
  "$(ls $C/l*.h | grep -vE '/(lua|luaconf|lualib|lauxlib)\.h$' | tr '\n' ' ')" \
  "$S/core.nuc $S/util.nuc config/release/src/luaconfig.nuc"
printf '| **Lua** | **%d** | **%d** | **%.2f** | **%d** | **%d** | **%.2f** |\n' $TC $TN \
  "$(echo "$TN / $TC" | bc -l)" $TCC $TNC "$(echo "$TNC / $TCC" | bc -l)"
row "Test library (ltests.c, ltests.h)" "$T/ltests.c $T/ltests.h" "tests/T/src/lua/tests.nuc config/tests/src/luaconfig.nuc"
row "Public headers' macros (lua.h, lauxlib.h, lualib.h) as the binding" \
  "$C/lua.h $C/lauxlib.h $C/lualib.h" "capi/src/luacapi.nuc"
