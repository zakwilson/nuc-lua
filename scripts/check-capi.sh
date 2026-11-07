#!/usr/bin/env bash
# The gate for the C API contract (PROMPT.md §6, §7.3): the headers, the layouts,
# the dynamic symbol table, the test module's coverage, and the matrix of modules
# by hosts. `--stock` runs only the stock host's column.
set -uo pipefail
source "$(dirname "$0")/env.sh"
W=$ROOT/build/capi
mkdir -p "$W"
PORT=$ROOT/build/lua
hosts="stock port"
[ "${1:-}" = "--stock" ] && hosts="stock"
fails=0
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }
ok() { echo "ok    $*"; }

# The stock headers are the contract.
for h in lua.h lauxlib.h lualib.h luaconf.h; do
  if cmp -s "$ROOT/include/$h" "$LUA_SRC/src/$h"; then ok "header $h"; else bad "header $h differs from $LUA_SRC/src"; fi
done

if "$ROOT/scripts/check-layout.sh" > "$W/layout.log" 2>&1; then ok "$(tail -1 "$W/layout.log")"
else bad "layout: see $W/layout.log"; fi

api_symbols() { nm -D --defined-only "$1" | awk '$3 ~ /^(lua|luaL|luaopen)_/ {print $2, $3}' | sort -k2; }
api_symbols "$REFLUA" > "$W/syms-stock.txt"
[ "$(wc -l < "$W/syms-stock.txt")" = 157 ] || bad "stock lua exports $(wc -l < "$W/syms-stock.txt") API symbols, not 157"
if [[ $hosts == *port* ]]; then
  api_symbols "$PORT" > "$W/syms-port.txt"
  if diff "$W/syms-stock.txt" "$W/syms-port.txt" > "$W/syms.diff"; then ok "port exports the 157 API symbols"
  else bad "symbol table: see $W/syms.diff"; fi
  # Anything else the port exports could bind a module's references (PROMPT.md §6.6).
  nm -D --defined-only "$PORT" | awk '$3 !~ /^(lua|luaL|luaopen)_/ && $2 ~ /[TDBR]/ {print $3}' \
    | sort > "$W/extra-exports.txt"
  echo "info  port exports $(wc -l < "$W/extra-exports.txt") other symbols ($W/extra-exports.txt)"
fi

# Every public function and function-like macro is named in tests/capi/capi.c,
# except the two stringizing helpers and the LUA_COMPAT_APIINTCASTS casts.
{
  awk '{print $2}' "$W/syms-stock.txt"
  for h in lua.h lauxlib.h lualib.h; do
    grep -oE '^#define[[:space:]]+(lua|luaL)_[A-Za-z0-9_]+\(' "$ROOT/include/$h" | sed -E 's/#define[[:space:]]+//; s/\($//'
  done | grep -vE '^luaL_(checkint|checklong|checkunsigned|optint|optlong|optunsigned)$'
} | sort -u > "$W/api-names.txt"
grep -oE '\b(lua|luaL|luaopen)_[A-Za-z0-9_]+' "$ROOT/tests/capi/capi.c" | sort -u > "$W/capi-used.txt"
missing=$(comm -23 "$W/api-names.txt" "$W/capi-used.txt" | tr '\n' ' ')
if [ -z "$missing" ]; then ok "capi.c names all $(wc -l < "$W/api-names.txt") functions and macros"
else bad "capi.c never names: $missing"; fi

# The matrix. Each module is built once and loaded unrebuilt into every host.
host_bin() { if [ "$1" = stock ]; then echo "$REFLUA"; else echo "$PORT"; fi; }
cell() { # name host sodir driver-args... ; stdin comes from the caller
  local name=$1 host=$2; shift 2
  (cd "$ROOT/build" && "$(host_bin "$host")" "$@") > "$W/$name.$host.out" 2>&1
}
for host in $hosts; do
  for kind in c n; do
    [ -f "$ROOT/build/so/$kind/mayi.so" ] || { bad "build/so/$kind/mayi.so is missing"; continue; }
    sleep 1 | cell "mayi-$kind-idle" "$host" "$ROOT/tests/capi/mayi.lua" "so/$kind" idle
    echo x | cell "mayi-$kind-ready" "$host" "$ROOT/tests/capi/mayi.lua" "so/$kind" ready
  done
  for kind in c n; do
    [ -f "$ROOT/build/so/$kind/capi.so" ] || { [ $kind = n ] && continue; bad "build/so/$kind/capi.so is missing"; continue; }
    sleep 0.2 | cell "capi-$kind" "$host" "$ROOT/tests/capi/driver.lua" "so/$kind"
  done
done
expect_mayi_idle=$'table\tfunction\nfalse\tfalse\tfalse\tfalse'
expect_mayi_ready=$'table\tfunction\ntrue'
for host in $hosts; do
  for kind in c n; do
    for mode in idle ready; do
      f=$W/mayi-$kind-$mode.$host.out
      [ -f "$f" ] || continue
      want=expect_mayi_$mode
      if [ "$(cat "$f")" = "${!want}" ]; then ok "mayi ($kind) $mode on $host"
      else bad "mayi ($kind) $mode on $host: $f"; fi
    done
  done
  for kind in c n; do
    f=$W/capi-$kind.$host.out
    [ -f "$f" ] || continue
    # The stock host running the C module is the control every other cell must equal.
    if [ "$kind.$host" = c.stock ]; then
      if tail -1 "$f" | grep -qx done; then ok "capi (c) on stock: control, $(wc -l < "$f") lines"
      else bad "capi (c) on stock did not finish: $f"; fi
    elif diff "$W/capi-c.stock.out" "$f" > "$W/capi-$kind.$host.diff"; then ok "capi ($kind) on $host"
    else bad "capi ($kind) on $host: see $W/capi-$kind.$host.diff"; fi
  done
done

if [ $fails -eq 0 ]; then echo "check-capi: pass"; else echo "check-capi: $fails failed"; exit 1; fi
