#!/usr/bin/env bash
# Checks the Nucleus view of lua.h (capi/) against the C compiler's: every size,
# offset and constant that compiled modules depend on (tests/layout/items.txt).
set -euo pipefail
source "$(dirname "$0")/env.sh"
W="$ROOT/build/layout"; mkdir -p "$W/src"
items="$ROOT/tests/layout/items.txt"
{
  echo '#include <stdio.h>'; echo '#include <stddef.h>'; echo '#include <stdalign.h>'
  echo '#include "lua.h"'; echo '#include "lauxlib.h"'; echo '#include "lualib.h"'
  echo 'int main(void) {'
  grep -v '^#' "$items" | while read -r k a b c; do case $k in
    size)  echo "  printf(\"size $a %lld\\n\", (long long)sizeof($a));" ;;
    align) echo "  printf(\"align $a %lld\\n\", (long long)alignof($a));" ;;
    off)   echo "  printf(\"off $a.$b %lld\\n\", (long long)offsetof($a, $b));" ;;
    const) echo "  printf(\"const $a %lld\\n\", (long long)($a));" ;;
    expr)  echo "  printf(\"expr $a %lld\\n\", (long long)($b));" ;;
    str)   echo "  printf(\"str $a [%s]\\n\", $a);" ;;
  esac; done
  echo '  return 0; }'
} > "$W/layout.c"
# Nucleus has no offsetof: a field's offset is its address minus its struct's.
{
  echo '(import luacapi)'
  grep -v '^#' "$items" | awk '$1=="off"{print $2}' | sort -u |
    while read -r t; do echo "(defvar g-$t:$t)"; done
  echo '(defn main ():i32'
  grep -v '^#' "$items" | while read -r k a b c; do case $k in
    size)  echo "  (printf \"size $a %lld\\n\" (as i64 (sizeof $a)))" ;;
    align) echo "  (printf \"align $a %lld\\n\" (as i64 (alignof $a)))" ;;
    off)   echo "  (printf \"off $a.$b %lld\\n\" (- (unsafe/cast i64 (ref g-$a '$b)) (unsafe/cast i64 &g-$a)))" ;;
    const) echo "  (printf \"const $a %lld\\n\" (as i64 $a))" ;;
    expr)  echo "  (printf \"expr $a %lld\\n\" (as i64 $c))" ;;
    str)   echo "  (printf \"str $a [%s]\\n\" $a)" ;;
  esac; done
  echo '  (return 0))'
} > "$W/src/main.nuc"
printf '{:name "layout" :cflags ["-I%s"] :deps {luacapi {:path "%s"}}}\n' \
  "$ROOT/include" "$ROOT/capi" > "$W/build-local.edn"
echo '{:name "layout"}' > "$W/build.edn"
cc -I"$ROOT/include" "$W/layout.c" -o "$W/layout-c"
(cd "$W" && "$NUCLEUS" build >/dev/null)
"$W/layout-c" > "$W/c.out"
"$W/build/layout" > "$W/nuc.out"
if diff "$W/c.out" "$W/nuc.out"; then
  echo "layout: $(wc -l < "$W/c.out") items match"
else
  echo "layout: MISMATCH (left C, right Nucleus)"; exit 1
fi
