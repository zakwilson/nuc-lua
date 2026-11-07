#!/usr/bin/env bash
# The port's dumps must be byte-identical to stock's (PROMPT §7.4): it dumps every
# suite file with each binary, stripped and not, and names the first differing
# function; so too for generated stress sources. Then each loads the other's
# dumps, a sample runs from both, and compile and load errors must read the same.
# The port's luac (luac/build/luac) must dump as string.dump does, list as stock
# luac does, and answer its options as stock luac does.
set -uo pipefail
source "$(dirname "$0")/env.sh"
LUA=$(realpath "${LUA:-$ROOT/build/lua}")
LUAC=$ROOT/reference/build/src/luac
PLUAC=$(realpath "${PLUAC:-$ROOT/luac/build/luac}")
T=$ROOT/tests/bytecode
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
fail=0; n=0
# Sources that reach the generator's rarer paths, beside the suite's.
mkdir "$W/stress" && "$REFLUA" "$T/gen-stress.lua" "$W/stress"
# luac -l prints addresses, so they are masked before listings are compared.
listing() { "${2:-$LUAC}" -l -l -p "$1" | sed -E 's/0x[0-9a-f]+/0x?/g'; }
for f in "$ROOT"/build/suite/*.lua "$W"/stress/*.lua; do
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
    "$PLUAC" $([ $s = 1 ] && echo -s) -o "$W/$b.$s.luac" "$f" &&
      cmp -s "$W/$b.$s.stock" "$W/$b.$s.luac" || { echo "check-bytecode: luac -o $b.lua (strip=$s) isn't string.dump's"; fail=1; }
  done
  cmp -s <(listing "$f") <(listing "$f" "$PLUAC") || { echo "check-bytecode: luac -l -l $b.lua lists differently"; fail=1; }
done
# luac's options, errors and luac.out, run from a scratch directory.
mkdir "$W/opt" && cd "$W/opt" && cp "$T/sample.lua" a.lua && echo 'return ...' > b.lua && echo 'x(' > bad.lua
for args in "" "-v" "-v a.lua" "-v -- a.lua" "-x" "-o" "-o -x a.lua" "-o - a.lua" "a.lua b.lua" \
            "-l a.lua b.lua" "-l" "-p" "-p a.lua" "-s a.lua" "-" "bad.lua" "nofile.lua" \
            "-o $W/none/x a.lua" "-l -l -p b.lua" "-- a.lua" "-l -"; do
  for c in "$LUAC" "$PLUAC"; do
    rm -f luac.out
    { echo 'return 1+1' | "$c" $args 2>&1 | sed -E "s|$c|luac|g; s/0x[0-9a-f]+/0x?/g" | od -c
      echo "status ${PIPESTATUS[1]}"; od -c luac.out 2>&1; } > "$W/opt.$([ "$c" = "$LUAC" ] && echo s || echo p)"
  done
  cmp -s "$W/opt.s" "$W/opt.p" || { echo "check-bytecode: 'luac $args' differs:"; diff "$W/opt.s" "$W/opt.p" | head -4; fail=1; }
done
cd "$ROOT"
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
# Compile errors read the same, and so do loads of corrupted dumps (with memory
# capped, as a corrupted size may ask for gigabytes).
diff <("$REFLUA" "$T/errors.lua" 2>&1) <("$LUA" "$T/errors.lua" 2>&1) > "$W/e" ||
  { echo "check-bytecode: compile errors differ:"; head -6 "$W/e"; fail=1; }
diff <(ulimit -v 1000000; "$REFLUA" "$T/badload.lua" 2>&1) <(ulimit -v 1000000; "$LUA" "$T/badload.lua" 2>&1) > "$W/e" ||
  { echo "check-bytecode: loading corrupted dumps differs:"; head -6 "$W/e"; fail=1; }
if [ $fail -eq 0 ]; then echo "check-bytecode: pass ($n dumps identical, cross-loading ok, luac as stock)"; else exit 1; fi
