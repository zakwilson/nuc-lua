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
| 3 Object model | done: `lctype`, `lzio`, `lmem`, `lobject`, `lstring`, `lfunc`, `ltm`, `ltable` |
| 4 Compiler | in progress: `lopcodes`, `llex`, `lcode`, `lparser`, `ldump`, `lundump` ported; `luac.c` left |
| 5–11 | not started |

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
- `1ae171b` a field of a union member is a place (ISSUE-032); no 256-macro cap (ISSUE-033)

### Still stock

The core except the object model: every module in `build.edn`'s `:c-sources`.
The object model is in `src/lua/` (`ctype`, `zio`, `mem`, `object`, `string`, `func`,
`tm`, `table`). Ported before it: `lua.c`
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
- M3's gate: the suite passed after each object-model module, as did `check-capi.sh`
  and the probes. Scripts that stress strings, metamethods, to-be-closed variables,
  varargs and tables printed the same as stock. A table-heavy loop ran in 0.41 s against
  stock's 0.38 s.
- M4 so far: after `lopcodes`, `llex`, `lcode` and `lparser`, the suite and every gate
  pass. Compiling the suite and a 140,000-constant chunk 20 times takes 3.2 s against
  stock's 3.1 s. Nesting 100 to 100,000 deep (parentheses, unary minus, blocks,
  constructors, calls, concatenations, assignment lists) fails or compiles as stock does.
  After `ldump` and `lundump`, loading every truncation of a dump and every byte of it
  set to 0, 0x80 and 0xff (`tests/bytecode/badload.lua`, 1696 results) reads as stock
  does, and `capi.c` reloads a dump from a fixed buffer.
- The spike: a Nucleus `luaopen_` module whose function raises with `luaL_error`
  (a real C variadic call) is caught by `pcall` in stock `lua`.

## Gates

- `scripts/check-capi.sh` (`--stock` for the stock column only): header diff,
  `check-layout.sh` (144 sizes, offsets and constants against the C compiler), the
  157-symbol table, `capi.c`'s coverage of all 209 functions and macros, the matrix.
- `scripts/build-libs.sh` builds `libs/*` into `build/so/n/`; `setup.sh` builds the C
  modules into `build/so/c/`.
- `scripts/check-probes.sh`.
- `scripts/check-bytecode.sh`: the 78 dumps of the suite's files and of
  `tests/bytecode/gen-stress.lua`'s sources (LOADKX, SETLIST's extra argument, absolute
  line info, folding corners, every variable kind), stripped and not, must be
  byte-identical to stock's; names the first differing function; cross-loads both ways;
  `tests/bytecode/errors.lua`'s compile errors and `tests/bytecode/badload.lua`'s
  corrupted loads must read the same.
- `scripts/check-tables.sh`: `luaP_opmodes` and `luai_ctype_` byte-identical to stock's.
- `scripts/check-suite.sh` runs the official suite (`LUA=` picks the binary).

## Next

M4, the compiler: `luac.c`, a second executable, its opcode names from the
`with-opcodes` rows. `code.nuc` holds `lcode.h`'s macros and the `expdesc`
union accessors (`u`, `set-u`, `ind`, `set-ind`, `uvar`, `set-uvar`) that `parser.nuc`
uses; `parser.nuc`'s `Block` is C's `BlockCnt` (ISSUE-037). `opcodes.nuc` generates `luaP_opmodes` from one
opcode row table (`with-opcodes`); `luac`'s opcode names come from the same rows.

The core modules import the internal headers (`-Ireference/build/src` in `:cflags`) for
their layouts. `src/lua/core.nuc` holds the internal headers' macros (`lobject.h`,
`lstate.h`, `lgc.h`, `ltm.h`, `ltable.h`, `lfunc.h`, `ldo.h`), with constants built
from function-like macros written out (ISSUE-029); `src/lua/ctype.nuc` holds `lctype.h`'s.
A namespaced module that names `Node` imports `lobject.h` a second time with prefix `c`
and writes `c/Node` (ISSUE-034). Every ported module is checked with `nm` for mangled
names (ISSUE-022), since a definition whose type misses the header's prototype links as an
overload and the C caller then binds to nothing.

## Open questions

None.
