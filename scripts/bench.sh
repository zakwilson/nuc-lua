#!/usr/bin/env bash
# Times bench/*.lua on the stock build and the port, best of RUNS (default 3),
# and appends the ratios to PROGRESS.md (PROMPT §7.5). Measured, not gated.
# NOAPPEND=1 prints only; a file argument runs that subset.
set -uo pipefail
source "$(dirname "$0")/env.sh"
STOCK=${STOCK:-$ROOT/reference/build/src/lua}  # either may be overridden, to compare other builds
PORT=${PORT:-$ROOT/build/lua}
RUNS=${RUNS:-3}
files=("$@")
[ ${#files[@]} -gt 0 ] || files=("$ROOT"/bench/*.lua)

best() {  # best wall time of RUNS, in ms
  local b=0 t0 t1 ms
  for _ in $(seq "$RUNS"); do
    t0=$(date +%s%N)
    "$1" "$2" >/dev/null || { echo "bench: $1 $2 failed" >&2; echo 0; return; }
    t1=$(date +%s%N)
    ms=$(( (t1 - t0) / 1000000 ))
    if [ "$b" -eq 0 ] || [ "$ms" -lt "$b" ]; then b=$ms; fi
  done
  echo "$b"
}

rows="| program | stock ms | port ms | ratio |"$'\n'"|---|---:|---:|---:|"
for f in "${files[@]}"; do
  s=$(best "$STOCK" "$f"); p=$(best "$PORT" "$f")
  r=$(awk -v s="$s" -v p="$p" 'BEGIN { printf (s > 0 ? "%.2f" : "-"), p / s }')
  rows+=$'\n'"| $(basename "$f" .lua) | $s | $p | $r |"
done
echo "$rows"
if [ -z "${NOAPPEND:-}" ]; then
  { echo; echo "### Benchmark, $(date +%F), Nucleus $(git -C "$NUCLEUS_HOME" rev-parse --short HEAD 2>/dev/null)"; echo; echo "$rows"; } >> "$ROOT/PROGRESS.md"
fi
