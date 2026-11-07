#!/usr/bin/env bash
# Runs the official suite (all.lua) on the port, or on LUA=<binary>, and reports
# the first failing file. stdin must be a pipe and the suite its own cwd.
set -uo pipefail
source "$(dirname "$0")/env.sh"
LUA=$(realpath "${LUA:-$ROOT/build/lua}")
SUITE=$ROOT/build/suite
LOG=$ROOT/build/suite.log
[ -f "$SUITE/all.lua" ] || { echo "check-suite: run scripts/setup.sh first" >&2; exit 2; }
start=$(date +%s)
(cd "$SUITE" && : | "$LUA" "$@" all.lua) > "$LOG" 2>&1
rc=$?
secs=$(( $(date +%s) - start ))
if [ $rc -eq 0 ] && grep -q '^final OK' "$LOG"; then
  echo "check-suite: pass (${secs}s)"
else
  first=$(grep -m1 -oE '[a-z0-9_]+\.lua:[0-9]+' "$LOG" | head -1)
  echo "check-suite: FAIL (exit $rc, ${secs}s) first failure: ${first:-unknown}; log: $LOG"
  tail -5 "$LOG"
  exit 1
fi
