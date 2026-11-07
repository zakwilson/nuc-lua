#!/usr/bin/env bash
# Checks that no stock object is linked into the port (PROMPT §10, M7): every
# global the stock objects define must, in build/lua, be absent or weak (W), the
# binding Nucleus gives a public defn; a C definition would be strong (T, D, B).
set -uo pipefail
source "$(dirname "$0")/env.sh"
BIN=${1:-$ROOT/build/lua}
STOCK=$ROOT/reference/build/src
ls "$STOCK"/l*.o >/dev/null 2>&1 || { echo "check-nm: run scripts/setup.sh first" >&2; exit 2; }
# lua.o and luac.o hold only 'main' and their statics
names=$(nm --defined-only -g "$STOCK"/l*.o 2>/dev/null | awk 'NF==3 && $2 ~ /[TDBR]/ {print $3}' | sort -u)
bad=$(nm "$BIN" | awk 'NF==3 && $2 ~ /^[TDBR]$/ {print $3}' | sort -u | comm -12 - <(echo "$names") | grep -vx main)
if [ -n "$bad" ]; then
  echo "check-nm: FAIL: stock definitions in $BIN:"; echo "$bad" | head -20
  exit 1
fi
echo "check-nm: pass ($(echo "$names" | wc -l) stock globals, none strong in $(basename "$BIN"))"
