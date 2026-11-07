#!/usr/bin/env bash
# Reruns every probe and says which issues still reproduce. Each probe's header
# carries `; run:` (with $NUCLEUSC, $P the probe, $D its directory, $W a scratch
# directory) and `; fixed-when-output:`, the last line a fixed compiler prints.
source "$(dirname "$0")/env.sh" || exit 1
cd "$ROOT/probes"
fixed=0; open=0
for P in "$PWD"/issue-[0-9][0-9][0-9].nuc; do
  id=$(basename "$P" .nuc)
  run=$(sed -n 's/^; run: //p' "$P")
  want=$(sed -n 's/^; fixed-when-output: //p' "$P")
  W=$(mktemp -d)
  got=$(D=$PWD P=$P W=$W NUCLEUSC=$NUCLEUSC bash -c "$run" 2>&1 | tail -1)
  rm -rf "$W"
  if [ "$got" = "$want" ]; then echo "FIXED       $id"; fixed=$((fixed+1))
  else echo "REPRODUCES  $id: $got"; open=$((open+1)); fi
done
echo "$fixed fixed, $open reproduce"
