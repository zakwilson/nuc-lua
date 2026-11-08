#!/usr/bin/env bash
# Builds the port in Lua's test configuration (tests/T: ltests.h, assertions on,
# the checked allocator and the T library) and runs the official suite with it,
# so that the T-only parts (api.lua, memerr.lua, …) run too (PROMPT §10, M10).
set -uo pipefail
source "$(dirname "$0")/env.sh"
(cd "$ROOT/tests/T" && "$NUCLEUS" build 2>&1 | grep -v "outside the project\|local path belongs" | grep -E "error|warning") && exit 1
# files.lua runs `lua` from PATH for its pipe tests
mkdir -p "$ROOT/build/T-bin"
ln -sf "$ROOT/tests/T/build/lua" "$ROOT/build/T-bin/lua"
PATH="$ROOT/build/T-bin:$PATH" LUA="$ROOT/tests/T/build/lua" LOG="${LOG:-$ROOT/build/suite-T.log}" \
  "$ROOT/scripts/check-suite.sh" "$@"
