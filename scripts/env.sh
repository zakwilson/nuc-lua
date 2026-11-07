# Sourced by every script. Finds the compiler and the sibling checkouts, so that
# nothing else in the repo names a path.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PARENT=$(dirname "$ROOT")

# A compiler built elsewhere may want another LLVM, so it must actually start.
runs() { [ -x "$1/build/nucleusc" ] && { "$1/build/nucleusc" --version >/dev/null 2>&1; [ $? -ne 127 ]; }; }
if [ -z "${NUCLEUS_HOME:-}" ]; then
  for d in "$PARENT/nucleus" "$PARENT/nucleus-work" "$ROOT/.nucleus-work"; do
    if runs "$d"; then NUCLEUS_HOME=$d; break; fi
  done
fi
if [ -z "${NUCLEUS_HOME:-}" ]; then
  echo "env.sh: no working Nucleus compiler; set NUCLEUS_HOME to a built checkout" >&2
  return 1 2>/dev/null || exit 1
fi
export NUCLEUS_HOME
export NUCLEUSC=$NUCLEUS_HOME/build/nucleusc
export NUCLEUS=$NUCLEUS_HOME/build/nucleus

export LUA_SRC=${LUA_SRC:-$PARENT/lua-5.5.1}
[ -d "$LUA_SRC" ] || LUA_SRC=$ROOT/reference/lua-5.5.1
export LUA_TESTS=${LUA_TESTS:-$PARENT/lua-5.5.1-tests}
[ -d "$LUA_TESTS" ] || LUA_TESTS=$ROOT/reference/tests/lua-5.5.1-tests
export REF=$ROOT/reference/build
export REFLUA=$REF/src/lua
export REFLUAC=$REF/src/luac
