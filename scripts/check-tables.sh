#!/usr/bin/env bash
# The port's constant tables must equal stock's byte for byte (PROMPT §7.6). It reads
# each symbol's bytes out of both executables with nm and objdump, without running them.
set -uo pipefail
source "$(dirname "$0")/env.sh"
LUA=$(realpath "${LUA:-$ROOT/build/lua}")
symbytes() {
  local a; a=$(nm "$1" | awk -v s="$2" '$3==s{print $1}')
  [ -n "$a" ] || { echo "missing"; return; }
  objdump -s --start-address=0x$a --stop-address=$(printf '0x%x' $((0x$a + $3))) "$1" |
    awk '/^ [0-9a-f]+ /{for(i=2;i<=5;i++) printf "%s", $i}' | cut -c1-$(( $3 * 2 ))
}
fail=0
for t in luaP_opmodes:85 luai_ctype_:257; do
  sym=${t%%:*}; n=${t##*:}
  p=$(symbytes "$LUA" "$sym" "$n"); r=$(symbytes "$REFLUA" "$sym" "$n")
  if [ "$p" = "$r" ] && [ "$p" != missing ]; then echo "ok    $sym ($n bytes)"
  else echo "FAIL  $sym: port $p"; echo "      stock $r"; fail=1; fi
done
[ $fail -eq 0 ] && echo "check-tables: pass" || { echo "check-tables: FAIL"; exit 1; }
