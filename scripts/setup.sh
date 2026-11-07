#!/usr/bin/env bash
# Provisions the stock reference. Idempotent; never touches the tree in $LUA_SRC.
set -eu
cd "$(dirname "$0")/.."
ROOT=$PWD
PARENT=$(dirname "$ROOT")
LUA_SRC=${LUA_SRC:-$PARENT/lua-5.5.1}
LUA_SHA=1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce
TESTS_SHA=da07b543872dc0bb2ff12aabd0c248578d78df3eb6b67efdc537a46d455c7f31

fetch() { # url sha dest-dir
  local tmp; tmp=$(mktemp -d)
  curl -fsSL "$1" -o "$tmp/t.tar.gz"
  echo "$2  $tmp/t.tar.gz" | sha256sum -c - >/dev/null
  mkdir -p "$3"
  tar -xzf "$tmp/t.tar.gz" -C "$3" --strip-components=1
  rm -rf "$tmp"
}

if [ ! -d "$LUA_SRC" ]; then
  LUA_SRC=$ROOT/reference/lua-5.5.1
  [ -d "$LUA_SRC" ] || fetch https://www.lua.org/ftp/lua-5.5.1.tar.gz $LUA_SHA "$LUA_SRC"
fi

TESTS=${LUA_TESTS:-$PARENT/lua-5.5.1-tests}
if [ ! -d "$TESTS" ]; then
  TESTS=$ROOT/reference/tests/lua-5.5.1-tests
  [ -d "$TESTS" ] || fetch https://www.lua.org/tests/lua-5.5.1-tests.tar.gz $TESTS_SHA "$TESTS"
fi

if [ ! -x reference/build/src/lua ]; then
  mkdir -p reference/build
  cp -r "$LUA_SRC"/. reference/build/
  make -C reference/build -j"$(nproc)" linux >/dev/null
fi

# The suite writes in its working directory, so it runs from a copy.
if [ ! -f build/suite/all.lua ]; then
  mkdir -p build/suite
  cp -r "$TESTS"/. build/suite/
fi
if [ ! -f build/suite/libs/lib1.so ]; then
  make -C build/suite/libs LUA_DIR="$ROOT/reference/build/src" >/dev/null
fi

# The C modules of the API matrix, built once; every host loads these same files.
mkdir -p build/so/c
for m in scratch/mayi.c tests/capi/capi.c; do
  so=build/so/c/$(basename "$m" .c).so
  [ "$so" -nt "$m" ] || gcc -shared -fPIC -I include "$m" -o "$so"
done
echo "setup: reference and suite ready"
