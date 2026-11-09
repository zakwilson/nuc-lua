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
| 9 Idiom pass | done: internals and private functions in kebab-case, shared macros in one place, `mathlib` in `defn-lua`; the layouts stay in the stock headers (ISSUE-037) |
| 10 T harness | done: all of `ltests.c` in `tests/T`, a configuration per build (`config/`); the suite passes with `T`, `api.lua` and `memerr.lua` included, in both stressed modes |
| 11 Final report | done: `ISSUES.md` opens with the executive summary, the final ranking, the line-count table and the code generation section |

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
- M9: after the renames every gate passes as before (suite, both stressed runs, the
  matrix, bytecode, tables, `nm` for both programs, 13 unit tests); the benchmark
  is unchanged, 0.93 to 1.13 times stock.
- M10: `scripts/check-T.sh` passes the whole suite (`final OK`, 28 files, `api.lua`
  and `memerr.lua` among them) on the port built with `ltests.h`, the checked
  allocator, `T` and assertions on; so do both stressed runs (`LUA=tests/T/build/lua
  scripts/check-gcstress.sh`). `memerr.lua`'s 44 minimum-allocation and memory
  figures equal those of stock built the same way (`build/ref-T/lua-T`). The release
  build's gates are unchanged.
- M11: every bug in `ISSUES.md` has a probe (or, if fixed, the Nucleus test of its
  fix) and every workaround is tagged in the code with its issue. Reading assembly
  beside clang's for the code generation section found ISSUE-055 (signed pointer
  comparisons), ISSUE-056 (`isalpha` through the PLT) and ISSUE-057 (no branch
  hint); `check-probes.sh` reports 9 fixed, 24 reproduce.
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
  and formatted, `op-modes` and `ctype-table` against stock's bytes, the token
  names, and the binding's macros on a live state.
- `scripts/check-bytecode.sh`: the 78 dumps of the suite's files and of
  `tests/bytecode/gen-stress.lua`'s sources (LOADKX, SETLIST's extra argument, absolute
  line info, folding corners, every variable kind), stripped and not, must be
  byte-identical to stock's; names the first differing function; cross-loads both ways;
  `tests/bytecode/errors.lua`'s compile errors and `tests/bytecode/badload.lua`'s
  corrupted loads must read the same. The port's `luac` (built by `nucleus build` in
  `luac/`; `PLUAC=` picks another) must dump as `string.dump`, list as stock `luac`, and
  answer its options as stock does.
- `scripts/check-tables.sh`: `op-modes` and `ctype-table` byte-identical to stock's
  `luaP_opmodes` and `luai_ctype_`.
- `scripts/check-nm.sh [binary]`: no global a stock object defines is strong in the
  port (Nucleus's public `defn`s are weak, C's are not).
- `scripts/check-suite.sh` runs the official suite (`LUA=` picks the binary).
- `scripts/check-gcstress.sh` runs it once per collector mode with the collector
  busy: incremental with `pause` 0 (a cycle always in progress), generational with
  `minormul` 1 (12 times the default's minor collections). On stock, `minormul` 0
  ran past ten minutes in `db.lua`'s hook tests, and `stepsize` 0 took nine and
  failed its count-hook test (`db.lua:605`). `MODES=`
  picks one, logs in `build/`; `SUITE=` (for `check-suite.sh` too) runs on a copy.
- `scripts/line-counts.sh` prints `ISSUES.md`'s line-count table.
- `scripts/check-T.sh` builds `tests/T` and runs the suite with it (log in
  `build/suite-T.log`); with `LUA=tests/T/build/lua`, `check-gcstress.sh` runs the
  stressed modes in that configuration.

## Next

All milestones are done. What remains is the user's: the test requests below, and
the five changes in `ISSUES.md`'s summary, which are Nucleus's to make. Feedback on
the port goes into the milestone it concerns.

## The idiom pass (M9)

- **Names.** The core's functions are no longer called by C, so they have Nucleus
  names: `luaH_get` is `table-get`, `luaV_execute` `vm-execute`, `luaD_throw`
  `do-throw`; one prefix per subsystem (`gc-`, `do-`, `state-`, `func-`, `debug-`,
  `table-`, `code-`, `mem-`, `obj-`, `op-`, `string-`, `tm-`, `vm-`, `lex-`,
  `parser-`, `zio-`), `luaY_parser` is `parse-chunk`, `luaU_dump` `dump-chunk`.
  Every private function, in the libraries too, is kebab-case (`str-find-aux`,
  `co-resume`, `pkg-require`). The public API (`lua_*`, `luaL_*`, `luaopen_*`)
  keeps its C names. Of stock `lua`'s globals, only the API's (`lua_*`, `luaL_*`,
  `luaopen_*`) and `main` are still in the port's symbol table.
- **Imports.** The stock headers had declared every core function, so a module
  called any other without importing it. Renamed, each module imports what it calls,
  and the core's imports form cycles, which Nucleus allows; its macros don't cross a
  cycle (ISSUE-052), so `core.nuc` now holds every macro two modules share. That
  merged 17 macros the migration had copied into two to four modules each, some
  subtly different (`tonumber`'s result, `get_nresults`'s mask, two `pcRel`s, two
  `code-at`s), and gave `code.nuc`'s `expdesc` accessors names no local would take
  (`exp-u`, `set-exp-u`, `exp-ind`, `exp-var`), since a macro in scope beats a local
  of its name (ISSUE-051). `lex.nuc`'s `next` macro became `next-char` for that reason.
- **Libraries.** `mathlib` is in the `defn-lua` style: the one-float functions are one
  row each in `def-float-fns`, and the others declare their arguments. The other
  libraries keep their explicit `luaL_check*` calls, since their checks are
  interleaved with optional and dependent arguments whose order the error messages
  reveal.
- **Held back still: the layouts.** The core reads `lobject.h`, `lstate.h` and the
  rest for its structs, as during the migration. Owning them means a `defstruct` for
  `lua_State`, which `lua.h` declares without a body, and a Nucleus struct can't
  complete it (ISSUE-037, now minor): every API function would cast from
  `lua_State*` to a second name. The function names moved; the types stay.
- **Benchmarks.** Unchanged (the renames don't touch code generation); nothing is
  near 1.5×. `vm-execute` is 26 KB against `luaV_execute`'s 16 KB, and `do-precall`
  1.1 KB against 0.6 KB; M11's code generation section looks at why.

The core modules import the internal headers (`-Ireference/build/src` in `:cflags`) for
their layouts. `src/lua/core.nuc` holds the internal headers' macros (`lobject.h`,
`lstate.h`, `lgc.h`, `ltm.h`, `ltable.h`, `lfunc.h`, `ldo.h`), with constants built
from function-like macros written out (ISSUE-029), and every macro that two modules
use (ISSUE-052); `src/lua/ctype.nuc` holds `lctype.h`'s. `parser.nuc`'s `Block` is C's
`BlockCnt` (ISSUE-037). `opcodes.nuc` generates `op-modes` from one opcode row table
(`with-opcodes`); `luac`'s `opnames` come from the same rows.
A namespaced module that names `Node` imports `lobject.h` a second time with prefix `c`
and writes `c/Node` (ISSUE-034). Every ported module is checked with `nm` for mangled
names (ISSUE-022), since a definition whose type misses the header's prototype links as an
overload and the C caller then binds to nothing.

## The T harness (M10)

- **Configuration.** `ltests.h` changes constants and turns on assertions, and a
  Nucleus file can't yet choose code by target, so the choice is a library: the
  `luaconfig` dependency is `config/release` for `lua` and `luac`, `config/tests` for
  `tests/T`. Each holds the few constants the port defines itself (`LUA-ASSERTS`,
  `LUAI_MAXSTACK`, `MINSTRTABSIZE`, `LUA-COMPAT-MATHLIB`) and three macros: the state's
  constructor (the checked allocator under test), `luai_openlibs` (adds `T`) and
  `luai_tracegc`. Constants `luaconf.h` defines (`LUAI_MAXCCALLS`, `LUAL_BUFFERSIZE`,
  `LUA_EXTRASPACE`, `STRCACHE_N`, `LUA_COMPAT_GLOBAL`, …) come from the header, which
  `-DLUA_USER_H=\"ltests.h\"` in `tests/T/build.edn` changes; the port's own copies
  of them are gone. `lua_assert` is a macro that compiles to nothing when
  `LUA-ASSERTS` is false; when true it aborts with the line.
- **`tests/T`.** Builds the same sources (`:source-root "../../src"`) with
  `tests/T/src/lua/tests.nuc`, all of `ltests.c` in Nucleus (1,409 lines against
  2,247): the checked allocator with its marks and fill, `T.checkmemory` walking every
  object, `T.testC`'s interpreter, `T.listcode`/`listk`, hooks, the panic test through
  `_setjmp`. ISSUE-053 renamed one helper; ISSUE-054 shapes the entry's import path.
- **Assertions.** `lgc.c`'s are restored (about 45) and pass in every run, since the
  collector is where a layout or barrier mistake would hide. About 280 in the other
  modules, and `lapi.c`'s `api_check`s, are not; the migration had dropped them and the
  suite's own checks cover those paths.
- **Left out.** `lua_lock`/`lua_unlock` and `ltests.h`'s user-state lock checks (the
  port has no lock calls); `LUA_RAND32`, the 32-bit generator; `l_sprintf`'s
  `memset`; `LUAI_STRICT_ADDRESS`; `LUA_USE_JUMPTABLE 0` (the port always threads).
- **Oracle.** `build/ref-T/lua-T` is stock built with `ltests.c` and `-Wl,-E`, so that
  `T`-mode results can be compared; `memerr.lua`'s minimum allocation for `dofile`
  varies by one between runs on both.

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

### Benchmark, 2026-11-07, Nucleus b8e711e

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 428 | 476 | 1.11 |
| closures | 427 | 411 | 0.96 |
| floats | 279 | 269 | 0.96 |
| gc | 624 | 594 | 0.95 |
| metamethods | 375 | 384 | 1.02 |
| patterns | 298 | 336 | 1.13 |
| strings | 195 | 183 | 0.94 |
| tables | 376 | 348 | 0.93 |

### Benchmark, 2026-11-08, Nucleus b8e711e

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 431 | 474 | 1.10 |
| closures | 423 | 406 | 0.96 |
| floats | 285 | 267 | 0.94 |
| gc | 619 | 616 | 1.00 |
| metamethods | 386 | 386 | 1.00 |
| patterns | 303 | 336 | 1.11 |
| strings | 195 | 184 | 0.94 |
| tables | 370 | 339 | 0.92 |

### Benchmark, 2026-11-08, Nucleus b8e711e

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 398 | 460 | 1.16 |
| closures | 425 | 423 | 1.00 |
| floats | 280 | 266 | 0.95 |
| gc | 634 | 597 | 0.94 |
| metamethods | 375 | 381 | 1.02 |
| patterns | 289 | 332 | 1.15 |
| strings | 176 | 171 | 0.97 |
| tables | 346 | 342 | 0.99 |

### Benchmark, 2026-11-08, Nucleus b8e711e

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 412 | 464 | 1.13 |
| closures | 429 | 426 | 0.99 |
| floats | 271 | 265 | 0.98 |
| gc | 632 | 592 | 0.94 |
| metamethods | 380 | 378 | 0.99 |
| patterns | 291 | 333 | 1.14 |
| strings | 182 | 173 | 0.95 |
| tables | 347 | 348 | 1.00 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 422 | 476 | 1.13 |
| closures | 430 | 428 | 1.00 |
| floats | 267 | 266 | 1.00 |
| gc | 631 | 597 | 0.95 |
| metamethods | 380 | 384 | 1.01 |
| patterns | 289 | 338 | 1.17 |
| strings | 181 | 170 | 0.94 |
| tables | 347 | 341 | 0.98 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 413 | 474 | 1.15 |
| closures | 429 | 430 | 1.00 |
| floats | 275 | 265 | 0.96 |
| gc | 645 | 583 | 0.90 |
| metamethods | 387 | 384 | 0.99 |
| patterns | 289 | 314 | 1.09 |
| strings | 178 | 171 | 0.96 |
| tables | 353 | 339 | 0.96 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 415 | 462 | 1.11 |
| closures | 427 | 426 | 1.00 |
| floats | 289 | 267 | 0.92 |
| gc | 643 | 591 | 0.92 |
| metamethods | 385 | 385 | 1.00 |
| patterns | 290 | 321 | 1.11 |
| strings | 181 | 170 | 0.94 |
| tables | 344 | 342 | 0.99 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 408 | 467 | 1.14 |
| closures | 426 | 426 | 1.00 |
| floats | 277 | 266 | 0.96 |
| gc | 638 | 597 | 0.94 |
| metamethods | 374 | 386 | 1.03 |
| patterns | 288 | 321 | 1.11 |
| strings | 179 | 174 | 0.97 |
| tables | 341 | 339 | 0.99 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 411 | 471 | 1.15 |
| closures | 426 | 431 | 1.01 |
| floats | 269 | 263 | 0.98 |
| gc | 649 | 593 | 0.91 |
| metamethods | 383 | 383 | 1.00 |
| patterns | 291 | 325 | 1.12 |
| strings | 181 | 171 | 0.94 |
| tables | 351 | 361 | 1.03 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 415 | 463 | 1.12 |
| closures | 426 | 431 | 1.01 |
| floats | 268 | 263 | 0.98 |
| gc | 638 | 613 | 0.96 |
| metamethods | 378 | 375 | 0.99 |
| patterns | 288 | 325 | 1.13 |
| strings | 183 | 167 | 0.91 |
| tables | 350 | 359 | 1.03 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 422 | 464 | 1.10 |
| closures | 428 | 441 | 1.03 |
| floats | 270 | 264 | 0.98 |
| gc | 642 | 586 | 0.91 |
| metamethods | 379 | 368 | 0.97 |
| patterns | 285 | 326 | 1.14 |
| strings | 185 | 170 | 0.92 |
| tables | 350 | 361 | 1.03 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 430 | 465 | 1.08 |
| closures | 427 | 435 | 1.02 |
| floats | 269 | 263 | 0.98 |
| gc | 633 | 585 | 0.92 |
| metamethods | 379 | 378 | 1.00 |
| patterns | 290 | 324 | 1.12 |
| strings | 181 | 169 | 0.93 |
| tables | 349 | 362 | 1.04 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 410 | 473 | 1.15 |
| closures | 427 | 429 | 1.00 |
| floats | 270 | 263 | 0.97 |
| gc | 640 | 589 | 0.92 |
| metamethods | 371 | 374 | 1.01 |
| patterns | 291 | 332 | 1.14 |
| strings | 178 | 168 | 0.94 |
| tables | 350 | 360 | 1.03 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 415 | 468 | 1.13 |
| closures | 426 | 411 | 0.96 |
| floats | 272 | 263 | 0.97 |
| gc | 642 | 606 | 0.94 |
| metamethods | 378 | 372 | 0.98 |
| patterns | 287 | 317 | 1.10 |
| strings | 180 | 170 | 0.94 |
| tables | 352 | 342 | 0.97 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 427 | 466 | 1.09 |
| closures | 428 | 411 | 0.96 |
| floats | 270 | 263 | 0.97 |
| gc | 630 | 621 | 0.99 |
| metamethods | 378 | 378 | 1.00 |
| patterns | 287 | 317 | 1.10 |
| strings | 179 | 173 | 0.97 |
| tables | 355 | 344 | 0.97 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 414 | 474 | 1.14 |
| closures | 426 | 413 | 0.97 |
| floats | 269 | 263 | 0.98 |
| gc | 635 | 615 | 0.97 |
| metamethods | 381 | 384 | 1.01 |
| patterns | 292 | 318 | 1.09 |
| strings | 177 | 166 | 0.94 |
| tables | 348 | 343 | 0.99 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 410 | 481 | 1.17 |
| closures | 427 | 414 | 0.97 |
| floats | 268 | 263 | 0.98 |
| gc | 637 | 616 | 0.97 |
| metamethods | 376 | 386 | 1.03 |
| patterns | 291 | 317 | 1.09 |
| strings | 179 | 173 | 0.97 |
| tables | 343 | 343 | 1.00 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 400 | 468 | 1.17 |
| closures | 429 | 413 | 0.96 |
| floats | 274 | 263 | 0.96 |
| gc | 642 | 607 | 0.95 |
| metamethods | 378 | 377 | 1.00 |
| patterns | 287 | 318 | 1.11 |
| strings | 179 | 176 | 0.98 |
| tables | 341 | 344 | 1.01 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 413 | 480 | 1.16 |
| closures | 427 | 411 | 0.96 |
| floats | 273 | 264 | 0.97 |
| gc | 643 | 610 | 0.95 |
| metamethods | 381 | 375 | 0.98 |
| patterns | 292 | 315 | 1.08 |
| strings | 180 | 171 | 0.95 |
| tables | 348 | 336 | 0.97 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 412 | 470 | 1.14 |
| closures | 429 | 411 | 0.96 |
| floats | 269 | 264 | 0.98 |
| gc | 631 | 607 | 0.96 |
| metamethods | 377 | 378 | 1.00 |
| patterns | 290 | 318 | 1.10 |
| strings | 183 | 171 | 0.93 |
| tables | 346 | 343 | 0.99 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 424 | 473 | 1.12 |
| closures | 428 | 431 | 1.01 |
| floats | 280 | 262 | 0.94 |
| gc | 636 | 612 | 0.96 |
| metamethods | 379 | 376 | 0.99 |
| patterns | 293 | 317 | 1.08 |
| strings | 181 | 171 | 0.94 |
| tables | 349 | 380 | 1.09 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 418 | 464 | 1.11 |
| closures | 427 | 434 | 1.02 |
| floats | 270 | 265 | 0.98 |
| gc | 638 | 615 | 0.96 |
| metamethods | 378 | 376 | 0.99 |
| patterns | 293 | 322 | 1.10 |
| strings | 180 | 171 | 0.95 |
| tables | 351 | 374 | 1.07 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 426 | 475 | 1.12 |
| closures | 429 | 433 | 1.01 |
| floats | 272 | 266 | 0.98 |
| gc | 642 | 611 | 0.95 |
| metamethods | 378 | 376 | 0.99 |
| patterns | 292 | 321 | 1.10 |
| strings | 181 | 173 | 0.96 |
| tables | 352 | 378 | 1.07 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 417 | 473 | 1.13 |
| closures | 423 | 432 | 1.02 |
| floats | 268 | 263 | 0.98 |
| gc | 642 | 596 | 0.93 |
| metamethods | 373 | 376 | 1.01 |
| patterns | 288 | 317 | 1.10 |
| strings | 182 | 173 | 0.95 |
| tables | 353 | 378 | 1.07 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 416 | 467 | 1.12 |
| closures | 428 | 432 | 1.01 |
| floats | 272 | 265 | 0.97 |
| gc | 632 | 626 | 0.99 |
| metamethods | 378 | 374 | 0.99 |
| patterns | 296 | 320 | 1.08 |
| strings | 179 | 167 | 0.93 |
| tables | 340 | 360 | 1.06 |

### Benchmark, 2026-11-09, Nucleus bd50e19

| program | stock ms | port ms | ratio |
|---|---:|---:|---:|
| calls | 410 | 462 | 1.13 |
| closures | 427 | 437 | 1.02 |
| floats | 277 | 265 | 0.96 |
| gc | 630 | 605 | 0.96 |
| metamethods | 377 | 375 | 0.99 |
| patterns | 288 | 317 | 1.10 |
| strings | 177 | 168 | 0.95 |
| tables | 355 | 364 | 1.03 |
