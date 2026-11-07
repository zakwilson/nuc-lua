#!/usr/bin/env bash
# The port's dumps must be byte-identical to stock's (PROMPT §7.4): it dumps every
# suite file with each binary, stripped and not, and names the first differing
# function. Then each loads the other's dumps, and a sample runs from both.
set -uo pipefail
source "$(dirname "$0")/env.sh"
LUA=$(realpath "${LUA:-$ROOT/build/lua}")
LUAC=$ROOT/reference/build/src/luac
T=$ROOT/tests/bytecode
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
fail=0; n=0
# luac -l prints addresses, so they are masked before listings are compared.
listing() { "$LUAC" -l -l -p "$1" | sed -E 's/0x[0-9a-f]+/0x?/g'; }
for f in "$ROOT"/build/suite/*.lua; do
  b=$(basename "$f" .lua)
  for s in 0 1; do
    "$REFLUA" "$T/dump.lua" "$f" "$W/$b.$s.stock" $s 2>/dev/null || continue
    "$LUA" "$T/dump.lua" "$f" "$W/$b.$s.port" $s || { echo "check-bytecode: $b.lua: the port can't dump it"; fail=1; continue; }
    n=$((n+1))
    if ! cmp -s "$W/$b.$s.stock" "$W/$b.$s.port"; then
      fail=1
      echo "check-bytecode: $b.lua (strip=$s) differs: $(cmp "$W/$b.$s.stock" "$W/$b.$s.port" | head -1)"
      diff <(listing "$W/$b.$s.stock") <(listing "$W/$b.$s.port") > "$W/d" 2>&1
      fn=$(listing "$W/$b.$s.stock" | head -n "$(grep -m1 -oE '^[0-9]+' "$W/d")" | grep -E '^(main|function) <' | tail -1)
      echo "  first differing function: ${fn:-unknown}"; head -6 "$W/d" | sed 's/^/  /'
    fi
  done
done
# Each implementation loads the other's dumps, and a sample runs both ways.
"$LUA" "$T/loadonly.lua" "$W"/*.stock || { echo "check-bytecode: the port refused a stock dump"; fail=1; }
"$REFLUA" "$T/loadonly.lua" "$W"/*.port || { echo "check-bytecode: stock refused a port dump"; fail=1; }
"$REFLUA" "$T/dump.lua" "$T/sample.lua" "$W/sample.stock" 0
"$LUA" "$T/dump.lua" "$T/sample.lua" "$W/sample.port" 0
want=$("$REFLUA" "$T/sample.lua" a b 2>&1)
for run in "$LUA $W/sample.stock" "$REFLUA $W/sample.port"; do
  got=$($run a b 2>&1)
  [ "$got" = "$want" ] || { echo "check-bytecode: '$run' printed differently:"; diff <(echo "$want") <(echo "$got") | head -5; fail=1; }
done
if [ $fail -eq 0 ]; then echo "check-bytecode: pass ($n dumps identical, cross-loading ok)"; else exit 1; fi
