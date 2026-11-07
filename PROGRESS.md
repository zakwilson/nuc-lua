# Progress

## The migration decision

**Hybrid, one module at a time.** The root `build.edn` builds `build/lua` from the
Nucleus sources in `src/` plus every stock module not yet ported, listed in
`:c-sources` and compiled from `reference/build/src/` (an unmodified copy of
`../lua-5.5.1` that `scripts/setup.sh` makes). Porting a module means writing its
Nucleus namespace and deleting its line from `:c-sources`; the suite must pass after
each one.

Why: the stock modules talk through narrow internal interfaces (`luaH_*`, `luaX_*`,
`luaD_*`), so one Nucleus module can stand in for one `.c` file as long as it keeps
the C names of what the remaining C calls and the C layouts of what it shares.
`build.edn`'s `:c-sources` made this cheap: the paths stay inside the project, so the
build gives no warning, and each `.o` is rebuilt only when its file changes. The cost
is that the remaining C is compiled by the build tool with `-O2` and
`-DLUA_USE_LINUX`, not by stock `make`, so a timing comparison against the
reference is only meaningful at the end.

Order: `lua.c`, `lauxlib.c` and the libraries first (public API only), then the
object model, the compiler, execution state, the collector and the VM (§10).

## Status

| Milestone | State |
|---|---|
| 0 Setup | done: env and setup scripts, reference and suite, spike, probes, hybrid build |
| 1 Binding and first library | done: `capi/` (both layers), layout gate, `libs/mayi`, `tests/capi/capi.c`, stock column |
| 2 Host and libraries | done: `lua.c`, `lauxlib.c`, `linit` and every standard library in Nucleus |
| 3 Object model | in progress: `lctype`, `lzio`, `lmem`, `lobject`, `lstring` ported; `lfunc`, `ltm`, `ltable` left |
| 4–11 | not started |

### Nucleus

Compiler: `.nucleus-work` on `lua-bugfixes` (see CLAUDE.md).

- `cd516e6` VA-0: a C variadic called through a `declare` (ISSUE-006)
- `336a93b` variadic functions (ISSUE-001), accepted as recommended in
  `design/lua-bugfixes/variadic-functions.md`
- `beb0472` header import of `RET (name)(args)` (ISSUE-002), defvar arrays of a
  header struct (ISSUE-003)
- `5dab7cb` an imported file defines a function its header declares (ISSUE-013)
- `0081d2a` an array field of a nested place decays into the place (ISSUE-023)
- `f282cfe` an attribute between a function's return type and its name (ISSUE-026);
  `C-MAX-PARAMS` is 64

### Still stock

The core: every module in `build.edn`'s `:c-sources`. Ported so far: `lua.c`
(`src/main.nuc`, namespace `lua.host`), `lauxlib.c` (`src/lua/aux.nuc`, `lua.aux`),
`linit.c` (`src/lua/init.nuc`) and the libraries in `src/lua/`: `baselib`, `corolib`,
`dblib`, `iolib`, `loadlib`, `mathlib`, `oslib`, `strlib`, `tablib`, `utf8lib`. A library's `luaL_Reg` table is built on the stack by
`lua.util/lua-newlib` (ISSUE-004). `luac.c` isn't built yet. `src/lua/util.nuc` holds what
the modules share from `llimits.h`, plus the workaround macros (`ch`, `bytes`, `cstr`,
`errno`, `set-errno`, `byte-diff`, `offsetof`, the `cast_*` family).

`src/lua.dynlist` limits the executable's dynamic table to `lua_*`, `luaL_*` and
`luaopen_*`, so a module loaded by `require` binds only the API, as with stock `lua`.

## Verified

- The reference passes `: | lua all.lua` in `build/suite`.
- `scratch/mayi.c` built by gcc and `libs/mayi` built by Nucleus behave the same in
  stock `lua`: `false` four times on an idle pipe, `true` with data, `require`
  returns a table.
- The port, with Nucleus `lua.c`, `lauxlib.c` and every library over the stock core
  (M2's gate), passes the suite (`scripts/check-suite.sh`) and the whole `check-capi.sh` matrix, both modules
  in both hosts. `lua.c`'s options checked by hand: `-v -e -i -E -`, `LUA_INIT`, usage.
- The spike: a Nucleus `luaopen_` module whose function raises with `luaL_error`
  (a real C variadic call) is caught by `pcall` in stock `lua`.

## Gates

- `scripts/check-capi.sh` (`--stock` for the stock column only): header diff,
  `check-layout.sh` (144 sizes, offsets and constants against the C compiler), the
  157-symbol table, `capi.c`'s coverage of all 209 functions and macros, the matrix.
- `scripts/build-libs.sh` builds `libs/*` into `build/so/n/`; `setup.sh` builds the C
  modules into `build/so/c/`.
- `scripts/check-probes.sh`.
- `scripts/check-suite.sh` runs the official suite (`LUA=` picks the binary).

## Next

M3, the object model: `lfunc`, `ltm`, `ltable`, with the suite after each.
The core modules import the internal headers (`-Ireference/build/src` in `:cflags`) for
their layouts; `src/lua/core.nuc` holds the `lobject.h`/`lstate.h` macros, with the
variant tags written out (ISSUE-029); `src/lua/ctype.nuc` holds `lctype.h`'s. These share layouts with the stock core, so each
struct is declared from the C headers' layout (`check-layout.sh` covers the public ones
only; the internal ones need their own `offsetof` check first).

## Open questions

None.
