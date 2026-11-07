# Progress

## The migration decision

**Hybrid, one module at a time** (complete at M7: no stock object is linked now).
The root `build.edn` built `build/lua` from the Nucleus sources in `src/` plus every
stock module not yet ported, listed in `:c-sources` and compiled from
`reference/build/src/` (an unmodified copy of
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

`luac` is a second project, `luac/build.edn`, whose entry is `src/luac.nuc` and whose
source root is the port's `src/`: a `build.edn` makes one program (ISSUE-039). Its
entry and source root warn at every build.

Order: `lua.c`, `lauxlib.c` and the libraries first (public API only), then the
object model, the compiler, execution state, the collector and the VM (§10).

## Status

| Milestone | State |
|---|---|
| 0 Setup | done: env and setup scripts, reference and suite, spike, probes, hybrid build |
| 1 Binding and first library | done: `capi/` (both layers), layout gate, `libs/mayi`, `tests/capi/capi.c`, stock column |
| 2 Host and libraries | done: `lua.c`, `lauxlib.c`, `linit` and every standard library in Nucleus |
| 3 Object model | done: `lctype`, `lzio`, `lmem`, `lobject`, `lstring`, `lfunc`, `ltm`, `ltable` |
| 4 Compiler | done: `lopcodes`, `llex`, `lcode`, `lparser`, `ldump`, `lundump`, `luac.c` |
| 5 Execution state | done: `lstate`, `ldebug`, `ldo`, `lapi` |
| 6 The collector | done: `lgc`; the suite passes collecting as often as it can, in both modes |
| 7 The VM | done: `lvm`, threaded dispatch; no stock object linked; benchmarked; user test request below |
| 8 Nucleus libraries | done: `libs/nucdemo`, `tests/capi/nuc`, `docs/writing-libraries.md`; the full matrix, two libraries at once, the unload path; user test request below |
| 9–11 | not started |

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
- `a64ac73` a later declarator keeps the base type (ISSUE-040); the fixed point
  holds from the third round
- `275b612`, `d2c75f7` a place under a macro call is a place, field or element (ISSUE-043)
- `b8e711e` a shared library's link takes `:link-args` (ISSUE-048)

### Still stock

None: `build.edn` has no `:c-sources`, and `scripts/check-nm.sh` finds no stock
definition in `lua` or `luac`. `lvm` is `vm.nuc`: dispatch is threaded, each opcode a
`label` ending in a `goto-ptr` through a global table filled on the first call
(ISSUE-045). `lstate`, `ldebug`, `ldo`, `lapi` and `lgc` are `state.nuc`,
`debug.nuc`, `do.nuc`, `api.nuc` and `gc.nuc`; `api.nuc`'s `lua_ident` is spelled out in bytes
(ISSUE-044); `do.nuc`'s `LongJmp` is C's `lua_longjmp` (ISSUE-037), its
`jmp_buf` a struct field, `_setjmp`/`_longjmp` by name. The object model is in `src/lua/`
(`ctype`, `zio`, `mem`, `object`, `string`, `func`, `tm`, `table`), and so is the
compiler (`opcodes`, `lex`, `code`, `parser`, `dump`, `undump`); `luac.c` is
`src/luac.nuc` (`lua.luac`). Ported before it: `lua.c`
(`src/main.nuc`, namespace `lua.host`), `lauxlib.c` (`src/lua/aux.nuc`, `lua.aux`),
`linit.c` (`src/lua/init.nuc`) and the libraries in `src/lua/`: `baselib`, `corolib`,
`dblib`, `iolib`, `loadlib`, `mathlib`, `oslib`, `strlib`, `tablib`, `utf8lib`. A library's `luaL_Reg` table is built on the stack by
`lua.util/lua-newlib` (ISSUE-004). `src/lua/util.nuc` holds what
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
  does, and `capi.c` reloads a dump from a fixed buffer. The port's `luac` dumps every
  suite and stress file as `string.dump` does, stripped and not, lists them (`-l -l`,
  addresses masked) as stock `luac` does, and answers 21 option cases (usage, `-v`,
  `--`, `-`, `-o -`, `luac.out`, errors) byte for byte. Compiling all of them ten times
  takes 2.28 s against stock `luac`'s 2.21 s.
- M6: with `lgc` in Nucleus, both stressed runs pass, as on stock. A script counting
  `__gc` sentinels sees the same number of cycles as stock in each mode.
- M7: with `lvm` in Nucleus, every gate passes (suite, both stressed runs, matrix,
  bytecode, tables, probes) and `check-nm.sh` finds no stock object in either program.
  The benchmark below runs at 0.92 to 1.14 times stock.
- M8: `tests/capi/nuc`, capi.c in Nucleus on the binding alone, prints the C
  module's transcript in stock `lua` and the port. It found one line of capi.c that
  depended on gcc's argument order (three `lua_stringtonumber` pushes as arguments of
  one `printf`), now sequenced. `libs/nucdemo` (a `Vector`-backed userdata with `__gc`
  and `__close`, a C closure, a `HashMap` anchored in a userdata, `luaL_Buffer`,
  registry references and callbacks, `Result`s raised as Lua errors, Lua errors
  caught as values, yields through `lua_callk` and `lua_pcallk`) prints
  `tests/capi/nucdemo.expected` in both hosts with `mayi` loaded beside it. Both
  `capi` modules load `nucdemo` and `mayi` into a fresh state, run a pending `__gc`
  at `lua_close`, and see both unmapped afterwards. `probes/issue-047.nuc` confirms
  that a `longjmp` skips `defer` and `with` cleanups; the rule that follows is in
  `docs/writing-libraries.md`.
- The spike: a Nucleus `luaopen_` module whose function raises with `luaL_error`
  (a real C variadic call) is caught by `pcall` in stock `lua`.

## Gates

- `scripts/check-capi.sh` (`--stock` for the stock column only): header diff,
  `check-layout.sh` (144 sizes, offsets and constants against the C compiler), the
  157-symbol table, `capi.c`'s coverage of all 209 functions and macros, the matrix.
- `scripts/build-libs.sh` builds `libs/*` and `tests/capi/nuc` into `build/so/n/`;
  `setup.sh` builds the C modules into `build/so/c/`. The matrix's rows: `mayi` (C,
  Nucleus), `capi` (C, Nucleus; equal to the C module on stock, and ending with the
  unload check), and `nucdemo` against `tests/capi/nucdemo.expected`.
- `scripts/check-probes.sh`.
- `nucleus test` builds and runs `tests/unit/main.nuc` (PROMPT §7.6): integer and float
  arithmetic at the edges, mixed integer/float comparisons past 2^53, numerals parsed
  and formatted, `luaP_opmodes` and `luai_ctype_` against stock's bytes, the token
  names, and the binding's macros on a live state.
- `scripts/check-bytecode.sh`: the 78 dumps of the suite's files and of
  `tests/bytecode/gen-stress.lua`'s sources (LOADKX, SETLIST's extra argument, absolute
  line info, folding corners, every variable kind), stripped and not, must be
  byte-identical to stock's; names the first differing function; cross-loads both ways;
  `tests/bytecode/errors.lua`'s compile errors and `tests/bytecode/badload.lua`'s
  corrupted loads must read the same. The port's `luac` (built by `nucleus build` in
  `luac/`; `PLUAC=` picks another) must dump as `string.dump`, list as stock `luac`, and
  answer its options as stock does.
- `scripts/check-tables.sh`: `luaP_opmodes` and `luai_ctype_` byte-identical to stock's.
- `scripts/check-nm.sh [binary]`: no global a stock object defines is strong in the
  port (Nucleus's public `defn`s are weak, C's are not).
- `scripts/check-suite.sh` runs the official suite (`LUA=` picks the binary).
- `scripts/check-gcstress.sh` runs it once per collector mode with the collector
  busy: incremental with `pause` 0 (a cycle always in progress), generational with
  `minormul` 1 (12 times the default's minor collections). On stock, `minormul` 0
  ran past ten minutes in `db.lua`'s hook tests, and `stepsize` 0 took nine and
  failed its count-hook test (`db.lua:605`). `MODES=`
  picks one, logs in `build/`; `SUITE=` (for `check-suite.sh` too) runs on a copy.

## Next

M9, the idiom pass (PROMPT §10): rename internals to Nucleus style now that no C
shares the layouts, revisit the early modules, redo what the migration held back, and
rerun the benchmarks. Then M10 (the `T` harness) and M11 (the final report). `code.nuc` holds `lcode.h`'s macros and the `expdesc`
union accessors (`u`, `set-u`, `ind`, `set-ind`, `uvar`, `set-uvar`) that `parser.nuc`
uses; `parser.nuc`'s `Block` is C's `BlockCnt` (ISSUE-037). `opcodes.nuc` generates `luaP_opmodes` from one
opcode row table (`with-opcodes`); `luac`'s `opnames` come from the same rows.

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

## User test request (M7)

The whole interpreter is now Nucleus; please try it on your machine. Nothing waits on
this.

Build:

```sh
# Nucleus at lua-bugfixes d2c75f7 (main 1e0fbb3 plus nucleus-patches/0001-0010)
git -C ../nucleus checkout lua-bugfixes   # or: git am nuc-lua/nucleus-patches/*.patch
make -C ../nucleus -j"$(nproc)"
export NUCLEUS_HOME=$(realpath ../nucleus)

# the port, on nuc-lua's main
scripts/setup.sh       # stock reference and suite; fetches them if ../lua-5.5.1* are absent
$NUCLEUS_HOME/build/nucleus build
(cd luac && $NUCLEUS_HOME/build/nucleus build)
scripts/build-libs.sh  # libs/mayi
```

Try:

- `build/lua` interactively, and on your own scripts; `luac/build/luac -l -l x.lua`.
- The gates: `scripts/check-suite.sh`, `scripts/check-gcstress.sh`,
  `scripts/check-capi.sh`, `scripts/check-bytecode.sh`, `scripts/check-nm.sh`.
- `NOAPPEND=1 scripts/bench.sh`, to see whether the ratios hold on your CPU.
- `scratch/mayi.c` (built by `setup.sh` into `build/so/c/`) and `libs/mayi` (into
  `build/so/n/`), each in each host:
  `sleep 1 | build/lua tests/capi/mayi.lua build/so/c idle` should print `table
  function` then `false` four times; `echo x | build/lua tests/capi/mayi.lua build/so/n
  ready` prints `true`. The same with `reference/build/src/lua`.

Known problems:

- Building `luac` warns twice that its entry and source root leave the project
  (ISSUE-039).
- `check-probes.sh` reports 16 probes that reproduce: those are open findings, not
  failures.
- `bench.sh`'s `calls` and `patterns` run about 1.13 times stock, not yet looked into.

## User test request (M8)

The Nucleus libraries are complete. On top of the M7 build above:

```sh
scripts/build-libs.sh      # libs/mayi, libs/nucdemo, tests/capi/nuc into build/so/n/
scripts/check-capi.sh      # the whole matrix, in both hosts
```

Try:

- `cd build && ../reference/build/src/lua ../tests/capi/nucdemo.lua so/n`, then the
  same with `./lua`: both print `tests/capi/nucdemo.expected`.
- `docs/writing-libraries.md`'s skeleton as a library of your own, loaded into both.
- `nm -D build/so/n/nucdemo.so`: only `luaopen_nucdemo`.

Known problems:

- Build Nucleus at `lua-bugfixes` `b8e711e` (patches 0001-0011), not the M7 request's
  `d2c75f7`: `libs/nucdemo` needs the fix for `:link-args` (ISSUE-048).
- A `defer` or `with` in a Lua C function is silently skipped by a Lua error
  (ISSUE-047); the guide's rule avoids it, the compiler doesn't check it.

## Benchmarks

`scripts/bench.sh` (PROMPT §7.5) appends each run here: best of three wall times, both
at `-O2`; a ratio above 1 is the port slower.

### Benchmark, 2026-11-07, Nucleus d2c75f7

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 420 | 479 | 1.14 |
| closures | 422 | 415 | 0.98 |
| floats | 274 | 260 | 0.95 |
| gc | 599 | 586 | 0.98 |
| metamethods | 369 | 368 | 1.00 |
| patterns | 291 | 330 | 1.13 |
| strings | 194 | 187 | 0.96 |
| tables | 367 | 339 | 0.92 |
