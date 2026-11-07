#!/usr/bin/env bash
# The suite with the collector running as often as it can, once per mode, to
# find missing write barriers that ordinary runs hide (PROMPT §10, M6). LUA= as
# for check-suite.sh; MODES= picks a subset of "incremental generational".
set -uo pipefail
source "$(dirname "$0")/env.sh"
declare -A PRELUDE=(
  # pause 0: a cycle starts as soon as the last one ends
  [incremental]='collectgarbage("incremental"); collectgarbage("param", "pause", 0)'
  # minormul 1: a minor collection per 1% of growth (0 runs db.lua for hours)
  [generational]='collectgarbage("generational"); collectgarbage("param", "minormul", 1)'
)
rc=0
for mode in ${MODES:-incremental generational}; do
  echo -n "$mode: "
  LOG=$ROOT/build/gcstress-$mode.log "$ROOT/scripts/check-suite.sh" -e "${PRELUDE[$mode]}" || rc=1
done
exit $rc
