#!/usr/bin/env bash
# Builds each Nucleus Lua library under libs/ (and tests/capi/nuc when it exists)
# and puts it in build/so/n/ under the name `require` looks for.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$ROOT/build/so/n"
for d in "$ROOT"/libs/*/ "$ROOT"/tests/capi/nuc/; do
  [ -f "$d/build.edn" ] || continue
  name=$(sed -n 's/.*:name "\([^"]*\)".*/\1/p' "$d/build.edn" | head -1)
  (cd "$d" && "$NUCLEUS" build >/dev/null)
  # The build tool always writes lib<name>.so (ISSUE-007).
  cp "$d/build/lib/lib$name.so" "$ROOT/build/so/n/$name.so"
done
ls "$ROOT/build/so/n"
