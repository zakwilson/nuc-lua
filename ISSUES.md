# Findings

Lua 5.5.1, all of it, in Nucleus: the core, the libraries, `lua`, `luac` and the
`T` test library. It passes the official suite in every configuration, dumps
byte-identical bytecode, loads C libraries built for stock `lua`, and runs at 0.90 to
1.13 times stock's speed. 57 findings; 12 were compiler bugs or limits, fixed on the
way (`lua-bugfixes`).

## Executive summary: the five changes that would help most

1. **Make a `longjmp` over a cleanup visible** (ISSUE-047). Every Lua C function can
   be left by a `longjmp`, which skips its `defer`s, `with` releases and `Drop`s
   without a word. A library author learns the rule from a leak. A
   `:may-longjmp` attribute on `lua_error` and the API, and a diagnostic for a
   cleanup that is live across such a call, would turn the rule into a check; the
   types already know where cleanups are.
2. **Give a shared library an export list** (ISSUE-005, 049, 007). A public `defn`
   in a `.so` is preempted by any same-named symbol in the process, and every
   standard-library instance it uses is exported, data included. Hidden by default,
   with `:exports` in `build.edn`, fixes both and the `lib` prefix too. Every
   library a Nucleus user writes for a C host meets this.
3. **Import a header's function-like and expression macros** (ISSUE-018, 029, 012,
   024, 046, 014, 056). The largest family of workarounds: `errno`, the wait macros,
   `LUA_VNUMINT`, string macros, `_IOFBF`, `SIG_DFL`, written out by hand and tied to
   glibc's private encodings. It also costs speed silently: `isalpha` becomes a PLT
   call where C inlines a table lookup, a third of the port's slowest benchmark.
4. **Let a header's declaration bind** (ISSUE-022, 037, 034). A `defn` whose type
   misses its header's prototype silently becomes a mangled overload, and the C
   caller links to nothing; a `defstruct` can't complete a struct the header
   declares, so the port can't own `lua_State`; a header type named like a prelude
   type is silently the prelude's. Each is cheap to diagnose where it happens.
5. **Arithmetic as C has it** (ISSUE-008, 027, 055, 028, 041, 025, 016). Integer to
   float takes `unsafe/cast`; `(- x)` on a float is `0 - x`, wrong for `-0.0`; `<` on
   pointers is signed; `bit-not` refuses unsigned operands; `sizeof` is signed; there
   is no byte literal. Each is small, and an interpreter meets all of them on every
   page; two give wrong answers rather than errors.

## Ranking

Ranked by porter pain removed per unit of language work.

| Rank | Issue | Claim | Severity | Kind | Status |
|---|---|---|---|---|---|
| 1 | ISSUE-005 | A library's public `defn` is preempted by any same-named symbol in the process | major | design | open |
| 2 | ISSUE-047 | A `longjmp` over a Nucleus frame skips its `defer` and `with` cleanups, silently | major | design | open |
| 3 | ISSUE-049 | A shared library exports every standard-library instance it uses, data included | major | design | worked-around |
| 4 | ISSUE-023 | An array field of a nested place decayed to a copy's address, losing every store | major | bug | fixed in nucleus `0081d2a` |
| 5 | ISSUE-032 | A store to a field of a union member was refused as a temporary | major | bug | fixed in nucleus `1ae171b` |
| 6 | ISSUE-043 | A place under a macro call, `&G(L)->mainth.l`, gave the address of a copy | major | bug | fixed in nucleus `275b612`, `d2c75f7` |
| 7 | ISSUE-033 | A compilation could hold at most 256 macros | blocker | bug | fixed in nucleus `1ae171b` |
| 8 | ISSUE-026 | A declaration with an attribute between its return type and its name was skipped | blocker | bug | fixed in nucleus `f282cfe` |
| 9 | ISSUE-022 | A definition that misses its header's prototype silently becomes a mangled overload | major | design | worked-around |
| 10 | ISSUE-004 | A function's address isn't a constant in an aggregate initializer | major | missing-feature | worked-around |
| 11 | ISSUE-013 | An imported file can't define a function its header declares | blocker | bug | fixed in nucleus `5dab7cb` |
| 12 | ISSUE-001 | A C variadic couldn't be defined in Nucleus | major | known-limitation | fixed in nucleus `336a93b` |
| 13 | ISSUE-002 | `RET (name)(args)`, how Lua declares every function, was skipped by a header import | blocker | known-limitation | fixed in nucleus `beb0472` |
| 14 | ISSUE-006 | Calling a C variadic by `declare` passed the tail unpromoted, with `%al` unset | major | bug | fixed in nucleus `cd516e6` |
| 15 | ISSUE-003 | A `defvar` array of a header's struct was refused as opaque | major | bug | fixed in nucleus `beb0472` |
| 16 | ISSUE-008 | Integer to float takes `unsafe/cast` | major | design | worked-around |
| 17 | ISSUE-027 | Unary minus on a float is `0 - x`, so `(- 0.0)` is `0.0`, not `-0.0` | major | bug | worked-around |
| 18 | ISSUE-055 | `<` on two pointers is a signed comparison | minor | bug | open |
| 19 | ISSUE-045 | A computed goto's jump table can be neither a local array nor a static one | minor | missing-feature | worked-around |
| 20 | ISSUE-037 | A `defstruct` can't complete a struct its header declares without a body, so the port can't own `lua_State` | minor | missing-feature | worked-around |
| 21 | ISSUE-052 | A macro doesn't cross an import cycle, so mutually recursive modules keep their shared macros in a leaf | minor | known-limitation | worked-around |
| 22 | ISSUE-051 | A local named like a macro in scope is the macro at the head of a form, so `(next 'v)` expands | minor | design | worked-around |
| 23 | ISSUE-019 | A header's `char *` is `(ptr i8)`, and an `if` won't join it with a string literal | minor | design | worked-around |
| 24 | ISSUE-021 | Pointers can't be subtracted | minor | missing-feature | worked-around |
| 25 | ISSUE-028 | `bit-not` of an unsigned operand is refused | minor | bug | worked-around |
| 26 | ISSUE-029 | A constant macro built with a function-like macro isn't imported: `LUA_VNUMINT` | minor | known-limitation | worked-around |
| 27 | ISSUE-030 | A `defconst` over a header constant is refused once a `defstruct` uses it as an array length | minor | bug | worked-around |
| 28 | ISSUE-031 | A row of a header's 2-D array field doesn't decay, so it can't be indexed | minor | bug | worked-around |
| 29 | ISSUE-034 | In a namespaced file, a header type named like a prelude type is silently the prelude's | minor | design | worked-around |
| 30 | ISSUE-018 | A header's expression macros aren't imported: `errno`, `WIFEXITED` | minor | known-limitation | worked-around |
| 31 | ISSUE-056 | glibc's `isalpha` is a macro, but the import calls the function: a PLT call per character | minor | interop | open |
| 32 | ISSUE-007 | A shared library is always named `lib<name>.so` | minor | tooling | worked-around |
| 33 | ISSUE-048 | A shared library's link ignored `:link-args` | minor | bug | fixed in nucleus (see PROGRESS.md) |
| 34 | ISSUE-010 | There is no `offsetof` | minor | missing-feature | worked-around |
| 35 | ISSUE-012 | A header's string macros aren't imported | minor | known-limitation | worked-around |
| 36 | ISSUE-011 | No `sizeof` of an expression, so no array length | minor | missing-feature | worked-around |
| 37 | ISSUE-015 | Only the entry file can export a strong symbol | minor | design | worked-around |
| 38 | ISSUE-016 | No byte literal: `\e` is a 32-bit Char and won't convert to `i8` | minor | design | worked-around |
| 39 | ISSUE-017 | A `CStr` can't be indexed | minor | design | worked-around |
| 40 | ISSUE-014 | `SIG_DFL` imports as the integer 0 | minor | interop | worked-around |
| 41 | ISSUE-040 | A later declarator in a field list (`*previous, *next`) imported as a bare `ptr` | minor | bug | fixed in nucleus `a64ac73` |
| 42 | ISSUE-042 | `=` on two `CStr`s compares contents, so a C pointer test ported as written reads through null | minor | design | worked-around |
| 43 | ISSUE-041 | `bit-not` of an unsigned value is refused: `-1` doesn't fit it | papercut | bug | worked-around |
| 44 | ISSUE-044 | A global `i8` array takes no string initializer, so `lua_ident` is spelled out in bytes | papercut | missing-feature | worked-around |
| 45 | ISSUE-046 | A header's array variable, `extern const char lua_ident[]`, isn't imported | papercut | known-limitation | worked-around |
| 46 | ISSUE-054 | A string-path import, `"z.nuc"`, isn't looked up beside the importing file, as the docs say | papercut | bug | worked-around |
| 47 | ISSUE-053 | Under `(set-ir-prefix "")` two namespaces can't each have a private helper of one name, and the error names one namespace for both | papercut | design | worked-around |
| 48 | ISSUE-050 | In a file with no `(ns …)`, a macro can't name the file's own private helpers | papercut | design | worked-around |
| 49 | ISSUE-024 | A `_`-prefixed macro isn't imported, even ISO C's `_IOFBF` | papercut | design | worked-around |
| 50 | ISSUE-020 | `set!` won't expand a macro in its place | papercut | missing-feature | worked-around |
| 51 | ISSUE-025 | `sizeof` is a signed integer, so comparing a size with it is refused | papercut | design | worked-around |
| 52 | ISSUE-035 | `unsafe/cast` from a function pointer to an integer is refused | papercut | bug | worked-around |
| 53 | ISSUE-036 | A `defvar`'s array initializer isn't macroexpanded before its shape is checked | papercut | bug | worked-around |
| 54 | ISSUE-038 | A parameter named like a special form is accepted, then misparsed at its use | papercut | design | worked-around |
| 55 | ISSUE-039 | A `build.edn` makes one program, and a second sharing its sources warns at every build | papercut | tooling | worked-around |
| 56 | ISSUE-057 | No branch hint (`likely`, `cold`): the VM's rare paths stay inline, 4.8 KB of `vm-execute` | papercut | missing-feature | open |
| 57 | ISSUE-009 | A library's diagnostics print three times | papercut | tooling | open |

## Line counts

Code lines exclude blank and comment-only lines; characters are the non-blank
characters outside comments, the fairer measure, since a Lisp line holds more than a
C one. `scripts/line-counts.sh` prints the table.

| Subsystem | C lines | Nucleus lines | Ratio | C chars | Nucleus chars | Ratio |
|---|---|---|---|---|---|---|
| Object model (lctype, lzio, lmem, lobject, lstring, lfunc, ltm, ltable) | 2319 | 1707 | 0.74 | 49749 | 53176 | 1.07 |
| Compiler (lopcodes, llex, lcode, lparser, ldump, lundump) | 4007 | 2989 | 0.75 | 82741 | 93059 | 1.12 |
| Execution state (lstate, ldebug, ldo, lapi) | 2961 | 2022 | 0.68 | 63056 | 66409 | 1.05 |
| Collector (lgc) | 1122 | 906 | 0.81 | 23127 | 28468 | 1.23 |
| VM (lvm) | 1508 | 1149 | 0.76 | 27896 | 30240 | 1.08 |
| Auxiliary library and init (lauxlib, linit) | 861 | 636 | 0.74 | 18646 | 19113 | 1.03 |
| Standard libraries (10) | 4721 | 3258 | 0.69 | 100270 | 94758 | 0.95 |
| Hosts (lua.c, luac.c) | 1223 | 736 | 0.60 | 23392 | 22326 | 0.95 |
| Internal headers' macros and limits (l*.h but the public four) | 2013 | 465 | 0.23 | 53872 | 17845 | 0.33 |
| **Lua** | **20735** | **13868** | **0.67** | **442749** | **425394** | **0.96** |
| Test library (ltests.c, ltests.h) | 1932 | 1257 | 0.65 | 41071 | 42671 | 1.04 |
| Public headers' macros (lua.h, lauxlib.h, lualib.h) as the binding | 434 | 180 | 0.41 | 16991 | 6918 | 0.41 |

The port is a third shorter in lines and about the same in characters: 10% longer in
the core, 4% shorter in the libraries and hosts. The core pays for casts that C makes
implicitly (`as`, `unsafe/cast`, the `cast_*` family) and for `(set! ((x 'f) 'g) v)`
where C writes `x->f.g = v`; the libraries gain from `defn-lua`, `lua-newlib` and
`case`. The headers row is not like for like: the port still takes its struct layouts
from the stock headers (ISSUE-037), so its 465 lines are the headers' macros and
limits only.

## Code generation

Stock `lua` is built by gcc, file by file. The port is one LLVM module, so the fair
comparison is stock built by the same backend (clang 19, `-O2`) with LTO:

| | gcc `-O2` | clang `-O2` | clang `-O2 -flto` | the same, no `l_likely` | port |
|---|---:|---:|---:|---:|---:|
| `luaV_execute` / `vm-execute` | 15,719 | 15,084 | 21,649 | 26,020 | 26,492 |
| `luaD_precall` / `do-precall` | 598 | 760 | 1,198 | 1,041 | 1,058 |
| `luaH_get` / `table-get` | 285 | 605 | 621 | 621 | 762 |
| program text | 278,310 | 279,041 | 340,265 | 341,793 | 370,779 |

- **Whole-program inlining** explains most of what M9 saw. Compiled as one module,
  the port inlines across files as stock does only under LTO: `do-precall` carries
  `growstack` and `extendCI` inline, and is smaller than stock's under LTO. It is a design win: Nucleus gets LTO's inlining by default.
- **No branch hint** (ISSUE-057). Stock marks its rare paths `l_unlikely`; without
  the hint, stock's `luaV_execute` grows from 21.6 KB to 26.0 KB, the port's size. The
  trap check that ends every opcode shows it: stock calls `luaG_traceexec` from 22
  places, unhinted stock from 56, the port from 80. Speed is unchanged within noise
  (the unhinted build ran 0.77 to 1.10 times the hinted one, no pattern), so this is
  size, not time.
- **Library calls that C inlines** (ISSUE-056). `patterns` is the one benchmark the
  port loses to every stock build (1.12 against gcc, 1.21 against clang LTO); its
  `gmatch` loop alone is 1.25. `match-class` calls `tolower`, `isalpha` and `islower`
  through the PLT per character; C's are glibc's inline table lookups. Stock built with
  `-D__NO_CTYPE`, which makes C call the same functions, runs `patterns` at 290 ms
  against 271, and `gmatch` at 171 against 148: half of `gmatch`'s gap, a third of the
  benchmark's. The rest I didn't trace.
- **Signed pointer comparisons** (ISSUE-055). Side by side, `singlematch`'s test
  `s < ms->src_end`:

  ```
  clang (C)                         Nucleus
  cmp    rdi,rsi                    cmp    QWORD PTR [rdi+0x8],rsi
  jbe    <singlematch+0xdb>         jle    <singlematch+0x39>
  ```

  The same code otherwise, but `jle` is signed. No x86-64 Linux user address reaches
  2^63, so the port runs correctly; on a 32-bit target it would not.
- **The remaining 9% of text** over stock under LTO is spread thin: the port has 616
  functions to stock's 479 (it inlines less in the parser: stock's `subexpr` is 7.4 KB
  with its callees inside, the port's 1.2 KB with them out of line), and only two public functions, 785 bytes, are
  never called. Floating point is the port's best case: `floats` runs at 0.96 of gcc's
  stock and 0.71 of clang's.

`scripts/bench.sh` takes `STOCK=` and `PORT=` to compare other builds; the clang
builds above are `clang -O2 [-flto] -DLUA_USE_LINUX` over `reference/build/src`.

## ISSUE-001: A C variadic couldn't be defined in Nucleus

- **Severity:** major
- **Kind:** known-limitation (`design/deferred/overview.md`)
- **Status:** fixed in nucleus `336a93b`, with the owner's tentative ruling on
  `design/lua-bugfixes/variadic-functions.md`
- **Probe:** `probes/issue-001.nuc` — expected `6 2.50`; before, `:varargs` was an
  unknown marker
- **Port sites:** `lua_pushfstring`, `luaL_error`, `lua_gc`, `lua_pushvfstring`
- **Workaround:** none needed now. PROMPT.md §6.4 planned a C shim in `src/c/` that
  walked the format and passed an array to Nucleus; it was never written.

Context: Lua's public API has three variadics and one `va_list` consumer, and a C
module reaches `lua_pushvfstring` with a real `va_list`. With no way to define one,
the port could not be all Nucleus. The design write-up measured LLVM's `va_arg`
per target; building it found that `va_arg` also crashes at `-O0` on x86-64 (the
fast register allocator reloads a spill it never wrote), so the compiler now
open-codes it for the two aggregate `va_list` classes.

## ISSUE-002: `RET (name)(args)` was skipped by a header import

- **Severity:** blocker
- **Kind:** known-limitation (`docs/structs-unions.md` named `int (f)(int);` as
  the canonical declarator the parser doesn't read)
- **Status:** fixed in nucleus `beb0472`
- **Probe:** `probes/issue-002.nuc` — expected `42`; actual `unknown: 'twice' — its C header declaration was skipped (./issue-002.h:1: a declaration shape the C header parser does not recognize)`
- **Port sites:** every function in `lua.h`, `lauxlib.h` and `lualib.h` (157)
- **Workaround:** would have been 157 hand-written `declare`s, drifting from the
  header; it was cheaper to fix.

Context: Lua declares `LUA_API int (lua_gettop) (lua_State *L);` so that a
function-like macro of the same name can't expand there. `(import-use "lua.h")`
brought in the types and constants and none of the functions. The diagnostic at
each use was clear; the cost was that the most common C idiom for protecting a
name from a macro was the one shape the docs gave up on.

## ISSUE-003: A `defvar` array of a header's struct was refused as opaque

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `beb0472`
- **Probe:** `probes/issue-003.nuc` — expected `16`; actual `array element: 'Reg' is an opaque type declared at ./issue-003.h:1; only pointers to it are valid`
- **Port sites:** every `luaL_Reg` table
- **Workaround:** none; it was fixed.

Context: the defvar prescan resolves the type before the header's layout is in, and
the provisional-length path checked opacity before returning. `sizeof` of the same
struct worked, so the diagnostic contradicted itself.

## ISSUE-004: A function's address isn't a constant in an aggregate initializer

- **Severity:** major
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-004.nuc` — expected `3`; actual `defvar: unsupported init symbol 'f'`
- **Port sites:** every `luaL_Reg` table (one per library), opcode and metamethod tables
- **Workaround:** fill the table at run time, or push each function in `luaopen_`.

Context: `(defvar g:(fn i32)(i32) f)` is accepted, as a run-time initializer, but
the same name inside `(array Reg (Reg "f" f) …)` is refused, though LLVM takes `@f`
as a constant. C writes `static const luaL_Reg regs[] = {{"mayi", f_mayi}, {NULL, NULL}};`.

## ISSUE-005: A library's public `defn` is preempted by any same-named symbol in the process

- **Severity:** major
- **Kind:** design
- **Status:** open
- **Probe:** `probes/issue-005.nuc` — expected `mine`; actual: the process dies of SIGHUP
- **Port sites:** every Lua C function in `libs/`
- **Workaround:** `defn-` for everything a library doesn't export.

Context: the first spike module defined `(defn raise (L:ptr):i32 …)` and pushed it
as a Lua function. `pcall(s.raise)` returned nothing at all: the call went to libc's
`raise`, because the `.so` exports every public `defn` with default visibility, and
even the module's own reference binds through the PLT. A C author writes `static`
by habit; in Nucleus, public is the default spelling. A library build has no
export list and no `-fvisibility=hidden`/`-Bsymbolic` switch. Since ISSUE-048's fix, a version
script in `:link-args` can make one (`libs/nucdemo/exports.map`); ISSUE-049 is why a
library using the standard library needs it.

## ISSUE-006: Calling a C variadic by `declare` passed the tail unpromoted

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `cd516e6`
- **Probe:** none of its own now: the open-tailed `declare` it needs was retired by
  the fix to ISSUE-001. The measurement is in the design doc, §2.2.
- **Port sites:** every `luaL_error` call written against a `declare`

Context: an `i16` of -300 arrived as 65236 and a `float` as garbage, and `%al` was
whatever the last call left, because the declared tail took the fixed-argument path.

## ISSUE-007: A shared library is always named `lib<name>.so`

- **Severity:** minor
- **Kind:** tooling
- **Status:** worked-around
- **Port sites:** `libs/mayi`, `libs/nucdemo`
- **Workaround:** the scripts copy `build/lib/libmayi.so` to `mayi.so`.

Context: `require "mayi"` searches `?.so`, so a Lua module is `mayi.so`. `build.edn`
has no key for the output name.

## ISSUE-008: Integer to float takes `unsafe/cast`

- **Severity:** major
- **Kind:** design
- **Status:** worked-around
- **Probe:** none needed: `(as f64 a)` with `a:i64` gives `as: lossy conversion from i64 to f64 -- use unsafe/cast`
- **Port sites:** the first was `build/idiom` (a test module); Lua's `cast_num`
  and every `luai_num*` on a mixed operand will follow
- **Workaround:** `(unsafe/cast f64 a)`

Context: Lua converts integers to floats everywhere arithmetic mixes them, and the
conversion is fully defined (it rounds). Nucleus files it under `unsafe`, beside
pointer reinterpretation, so the port's arithmetic will be dotted with `unsafe`
where nothing is unsafe, and the word stops meaning anything when the real
reinterpretations (`gco2ts`) come. The same holds for float to integer, which is
undefined out of range and does deserve a check; Lua checks it itself
(`luaV_flttointns`).

## ISSUE-009: A library's diagnostics print three times

- **Severity:** papercut
- **Kind:** tooling
- **Status:** open
- **Probe:** any library project with an error: `nucleus build` prints it once for
  `build/obj/<name>.o`, once for `build/include/<name>.nuch` and once for
  `build/include/<name>.h`

Context: the three outputs are separate compiler runs over the same source.

## ISSUE-010: There is no `offsetof`

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Port sites:** `scripts/check-layout.sh`; `string.nuc` (`sizestrshr`,
  `luaS_sizelngstr`, `udatamemoffset`); `lfunc.h`'s `sizeofCclosure` and `ltable.c` will follow
- **Workaround:** the layout gate takes a global of the struct and subtracts its
  address from the field's. The core has `offsetof` in `util.nuc`, which reads the
  field's address off a struct pointer cast from the constant 4096; it folds to a constant.

Context: the layout gate needs every field offset of `luaL_Buffer` and `lua_Debug`.
The compiler has the number; the docs say `make layout-test` compares Nucleus's
`offsetof` with C's, but no form spells it.

## ISSUE-011: No `sizeof` of an expression, so no array length

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `(sizeof (type-of regs))` gives `unknown type: type-of`; `sizeof` takes only a type
- **Port sites:** `capi/src/luacapi.nuc` (`luaL_newlibtable`), and every
  `sizeof(arr)/sizeof(arr[0])` in the C (`lstrlib.c`, `lbaselib.c`, `ltm.c`)
- **Workaround:** `luaL_newlibtable` counts entries up to the `{NULL, NULL}`
  sentinel at run time; a table with a known length repeats it as a constant.

Context: C's `luaL_newlibtable(L, l)` is `lua_createtable(L, 0, sizeof(l)/sizeof((l)[0]) - 1)`.
A macro can't ask for an array variable's type or length, so the macro can't keep
the C signature without a loop the C didn't need.

## ISSUE-012: A header's string macros aren't imported

- **Severity:** minor
- **Kind:** known-limitation (`docs/compiler.md`, "Integer constants from a C header":
  "string bodies … are skipped")
- **Status:** worked-around
- **Port sites:** `capi/src/luacapi.nuc` (32 `defconst`s), and `LUA_PATH_DEFAULT`,
  `LUA_NUMBER_FMT`, `LUA_SIGNATURE` in the port
- **Workaround:** each is written out as a `defconst`, and `scripts/check-layout.sh`
  diffs every one against the C compiler's value so none can drift.

Context: `LUA_FILEHANDLE`, `LUA_LOADED_TABLE` and `LUA_VERSION` are as much the API as
`LUA_REGISTRYINDEX`, and a module author reaches for them by name. Most are a plain
literal (`#define LUA_FILEHANDLE "FILE*"`); the rest are adjacent literals and macros
(`LUA_VERSION_MAJOR "." LUA_VERSION_MINOR`), which the integer folder's machinery
could concatenate.

## ISSUE-013: An imported file can't define a function its header declares

- **Severity:** blocker
- **Kind:** bug
- **Status:** fixed in nucleus `5dab7cb`
- **Probe:** `probes/issue-013.nuc` — expected `3 60`; actual `failed to parse generated
  IR ... invalid redefinition of function 'bar'`, and for a `:varargs` definition
  `defn: variadic 'sum' can't be overloaded`
- **Port sites:** every module of the port that implements part of the API:
  `lauxlib` (48 functions), each `luaopen_`, later `lapi`
- **Workaround:** none short of putting every API function in the entry file.

Context: the port's `lua.aux` implements `luaL_*` and imports `lua.h` for the types. In
the entry file that works: the prescan binds the name before the header is read, so the
header skips its `declare`. In an imported file the header still emitted `declare
@luaL_where` beside the `define`, and LLVM refused the module. A `:varargs` definition
failed earlier: the signature prescan registered it as non-variadic (a slip in the
variadics change itself), so it didn't match the C declaration, which then joined it as
an overload.

## ISSUE-014: `SIG_DFL` imports as the integer 0

- **Severity:** minor
- **Kind:** interop
- **Status:** worked-around
- **Port sites:** `src/main.nuc` (2)
- **Workaround:** `(defconst sig-dfl null)`

Context: `#define SIG_DFL ((__sighandler_t) 0)` folds as an integer constant, so it
arrives as `i32` and `(setsignal SIGINT SIG_DFL)` is a type error against the handler
parameter. A cast to a pointer type in a macro body should either give a null of that
type or be skipped with a reason, not become an `int`.

## ISSUE-015: Only the entry file can export a strong symbol

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Port sites:** all 157 API symbols as the port takes them over
- **Workaround:** `scripts/check-capi.sh` compares function against data, not strong
  against weak.

Context: linkage follows ownership, so every `defn` in an imported file is `weak_odr`, and
`nm -D` on the port shows `W lua_pushinteger` where stock shows `T`. Loading works the same,
since the executable comes first in the lookup order. But a program built from several
files has no way to say "this is the one definition", and a weak symbol in a library
can be silently replaced by any strong one.

## ISSUE-016: No byte literal

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Port sites:** every character test in `lua.c`, `lauxlib.c`, `llex.c`, `lstrlib.c`
- **Workaround:** `lua.util/ch`, a macro that turns `\e` into the integer literal 101.

Context: C writes `if (argv[i][1] == 'e')`. In Nucleus `\e` is a `Char`, a 32-bit
codepoint, and `(= (aref a 1) \e)` compares an `i8` with it; `(as i8 \e)` is refused as
lossy, and `(char "e")` is a `Char` too. A byte-oriented interpreter compares bytes on
almost every line of its lexer and pattern matcher.

## ISSUE-017: A `CStr` can't be indexed

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Port sites:** `src/main.nuc`, `src/lua/aux.nuc`, and every C string walk to come
- **Workaround:** `lua.util/bytes`, `(as (ptr i8) (as ptr s))`; pointer arithmetic then
  needs `unsafe/ptr+`, and a result going back to C needs `(as CStr (as ptr p))`.

Context: `aref` on a `CStr` is `operand must be typed pointer`. Every `const char *` in a
C API imports as `CStr`, so walking one takes two conversions each way.

## ISSUE-018: A header's expression macros aren't imported: `errno`, `WIFEXITED`

- **Severity:** minor
- **Kind:** known-limitation
- **Status:** worked-around
- **Port sites:** `luaL_execresult` (`WIFEXITED`, `WEXITSTATUS`, `WIFSIGNALED`,
  `WTERMSIG`), every `errno` in `lauxlib.c`, `liolib.c`, `loslib.c`
- **Workaround:** `lua.util/errno` and `set-errno` expand to `(deref (__errno_location))`;
  the wait macros are written out by hand from glibc's bit layout in `aux.nuc`.

Context: `errno` is `(*__errno_location ())` and the wait macros are function-like
macros over shifts and masks. Neither imports, so the port spells out glibc's private
definitions, which a header import exists to spare a porter, and which tie the port to
glibc's encoding of a wait status.

## ISSUE-019: A header's `char *` is `(ptr i8)`, and an `if` won't join it with a string literal

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Port sites:** `luaL_typeerror`, `luaL_fileresult`, `luaL_tolstring`, the panic
  function; every `cond x ? lua_tostring(...) : "literal"` in the libraries;
  `errorlimit`, `jumpscopeerror`, `getvarattribute` in `parser.nuc`
- **Workaround:** `lua.util/cstr`, `(as CStr (as ptr p))`.

Context: a `const char *` parameter imports as `CStr`, but a return value or a struct
field of the same type imports as `(ptr i8)`. A `let` with a `CStr` slot accepts a
`(ptr i8)`, yet `(if c (lua_tostring L -1) "nil")` is refused: "value is either (ptr i8)
or CStr". C's `?:` with a string literal on one side is common in Lua's sources.

## ISSUE-020: `set!` won't expand a macro in its place

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Port sites:** `errno = 0` in `luaL_loadfilex` (3), `liolib.c`, `loslib.c`; the
  `expdesc` union's setters (`set-u`, `set-ind`, `set-uvar`) in `code.nuc`
- **Workaround:** a second macro, `set-errno`.

Context: with `(defmacro errno () ...)` expanding to a `deref` place, `(set! (errno) 0)`
is refused as "not an assignable place". Lisp's `setf` expands the place first; here a
macro that names a place can be read but not written.

## ISSUE-021: Pointers can't be subtracted

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Port sites:** `luaL_addgsub`; `lstrlib.c` measures every match as `e - s`, and
  `llex.c`, `lobject.c` do the same
- **Workaround:** `lua.util/byte-diff`, which casts both to `i64` with `unsafe/cast`.

Context: `unsafe/ptr+` exists, but there is no difference, so `p - q` goes through
integers: two unchecked casts for an operation C considers safe within one array, and
the element size is the porter's to remember for anything wider than a byte.

## ISSUE-022: A definition that misses its header's prototype silently becomes a mangled overload

- **Severity:** major
- **Kind:** design
- **Status:** worked-around
- **Port sites:** `luaL_checkoption`
- **Workaround:** the parameter is declared `ptr`, as the import reads
  `const char *const lst[]`, and cast to `(ptr CStr)` inside.

Context: written as `lst:(ptr CStr)`, the definition didn't match the header's
prototype, so it was registered as an overload named
`luaL_checkoption.plua_State.i32.cstr.pcstr`, with no diagnostic. The executable failed
to link; in a `.so` the C name would just be missing until something loads it. Under
`(set-ir-prefix "")`, where a definition exists to implement a C name, a mismatch with
the header's prototype should be an error that shows both signatures. Finding the
right spelling took a probe, since nothing shows how a header's types were read.

## ISSUE-023: An array field of a nested place decayed to a copy's address

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `0081d2a`
- **Probe:** `probes/issue-023.nuc` — expected `65 1`; actual `0 0`
- **Port sites:** `luaL_buffinit` (`B->b = B->init.b`), so every `luaL_Buffer`;
  `buffonstack`
- **Workaround:** `(ref (B 'init) 'b)`, before the fix.

Context: `((B 'init) 'b)` loaded `init` into a temporary and decayed the array there, so
the buffer pointed at dead stack: `string.format` returned blanks and error messages were
garbage. nuc-doom ISSUE-040 had fixed the same thing for a binding receiver. A second
case surfaced while fixing it: `(ref ((aref p i) 'in) 'b)` copied too, because the
element of a `&T` had no type for the receiver check.

## ISSUE-045: A computed goto's jump table can be neither a local array nor a static one

- **Severity:** minor
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-045.nuc` — expected `12`; actual `(array T N) is a storage
  type: it is valid only as a defvar type or a defstruct / (struct ...) field type`
- **Port sites:** `luaV_execute` in `vm.nuc`
- **Workaround:** a module-level `(defvar- vm-disptab:(array ptr 85))`, filled with
  `label-addr`s on the first call, when its first slot is still null.

Context: `lvm.c` threads its dispatch through `static const void *const disptab[] =
{&&L_OP_MOVE, …}`, which C compiles to a constant table in read-only data. Nucleus
has `label-addr` and `goto-ptr`, and they work, but the table has nowhere to live: a
function can't hold an array, has no `static` local, and a global's initializer can't
name a label. The first port `alloca`'d it and filled 85 slots at each call, which
cost nothing for Lua-to-Lua calls (they stay in one frame) but made a metamethod-heavy
benchmark 1.28 times stock, since each metamethod re-enters `luaV_execute` from C;
filled once into a global it runs at 0.97. The global is written on first use, so two
threads starting their first Lua call at once race to store the same values. A local
array, or `label-addr` in a `defconst`/`defvar` aggregate inside the function, would
let the compiler emit C's constant table.

## ISSUE-046: A header's array variable, `extern const char lua_ident[]`, isn't imported

- **Severity:** papercut
- **Kind:** known-limitation
- **Status:** worked-around
- **Probe:** `probes/issue-046.nuc` — expected `UTC`; actual `undefined: 'tzname' — its
  C header declaration was skipped (/usr/include/time.h:224: an array variable)`
- **Port sites:** `tests/capi/nuc/src/capi.nuc`
- **Workaround:** `(extern lua_ident:(array i8 1))` in the module that reads it: the
  length is a guess, harmless while only the address is read, and wrong anywhere
  the definition is also compiled.

Context: `lua.h` declares one variable, `extern const char lua_ident[]`, and the
importer skips it, saying why (to its credit). Declaring it in the binding instead,
as `(extern lua_ident:(array i8 1))`, then broke the port: a program that both
defines the array (`api.nuc`, 129 bytes) and imports the binding is refused, since
the two lengths differ, though C accepts `extern const char x[];` beside any
definition. So only `tests/capi/nuc`, which never defines it, declares it. The Nucleus test module is the first
code to read it from outside the core. An unsized array could import as an `extern`
of `(array T 0)`, or as a pointer-valued name, as C's decay treats it.

## ISSUE-047: A `longjmp` over a Nucleus frame skips its `defer` and `with` cleanups, silently

- **Severity:** major
- **Kind:** design
- **Status:** open
- **Probe:** `probes/issue-047.nuc` — expected `cleanups 2`; actual `cleanups 0` (the
  same code without the jump prints 2)
- **Port sites:** every Lua C function in the port and in `libs/`; the rule below is
  `docs/writing-libraries.md`'s
- **Workaround:** the rule: a function holds no `defer`, no `with`-owned binding and no
  `Drop` value across a call that can raise or yield. Owning work runs in helpers that
  never call Lua and return a `Result`; the Lua function raises after they return.
  What must live while Lua runs is anchored in a userdata whose `__gc` releases it
  (`nucdemo`'s `words` keeps its `HashMap` so).

Context: `lua_error`, `luaL_error`, every `luaL_check*`, and any API call that can
allocate, all leave by `longjmp` to the `pcall` that is waiting, in C or in the port's
`do.nuc`. Nucleus's cleanups are lexical, emitted at each exit the compiler sees, so
the jump runs none of them: the probe's `defer` and its `Drop` binding are skipped,
and nothing says so. Lua's own C code has the same rule, kept by habit; in Nucleus,
`with` and `defer` are the idiomatic spelling and look safe. The port follows the rule
by construction (it is C's code). In `nucdemo` it shaped the design: `parse-int` owns
its buffer through a `with` and returns `!i64`; `parse` raises only after it returns.

What would help, cheapest first: (1) an attribute for a declared function that may
not return normally (`:may-longjmp`, given in the binding to `lua_error` and friends,
and implied for anything calling `_longjmp`), and a compile-time error when an armed
`defer` or owned binding is live across a call to one; (2) a cleanup form that also
runs when the frame is jumped over, which needs an unwinder: Lua can throw C++
exceptions instead of `longjmp` (`LUAI_THROW`), and Nucleus could emit its cleanups as
landing pads, though a stock C host would still `longjmp`.

## ISSUE-049: A shared library exports every standard-library instance it uses, data included

- **Severity:** major
- **Kind:** design
- **Status:** worked-around
- **Probe:** none standalone: it takes two libraries and a host. In
  `libs/nucdemo` without its version script, `nm -D` lists 255 symbols: `luaopen_nucdemo`,
  253 weak functions (`nuc_conj.pnuc_Vector.f64.f64`, `nuc_heap-allocate`, …) and two
  data objects, `nuc_heap` and `nuc_g-handler-top`.
- **Port sites:** `libs/nucdemo/build.edn`
- **Workaround:** a version script, `libs/nucdemo/exports.map`, exporting
  `luaopen_nucdemo` only, through `:link-args` (which needed ISSUE-048's fix).

Context: every program or library that imports `nucleus.vector` instantiates the
methods it uses, as `weak_odr` symbols with default visibility, and the prelude's
globals come along. `require` opens a module `RTLD_LOCAL`, so two libraries keep their
own copies; but `package.loadlib(path, "*")` opens one `RTLD_GLOBAL`, and from then on
the next Nucleus library binds to the first one's instances: with two copies of
`nucdemo` (as `nd1`, loaded with `"*"`, and `nd2`, required), `LD_DEBUG=bindings`
shows 140 of `nd2`'s references, the heap allocator and `drop` among them, bound to
`nd1`. That is harmless only while both were built by the same compiler from the same
standard library; built by different ones, `nd2` runs `nd1`'s `Vector` code on its own
layout. The same happens under a Nucleus host linked with `-Wl,-E`. What would help: a
library build that gives everything but its public `defn`s hidden visibility (an
`:exports` list in `build.edn`, or hidden by default for `:shared`).

## ISSUE-048: A shared library's link ignored `:link-args`

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed in nucleus (see PROGRESS.md)
- **Probe:** `nucleus` test `bt7-shared-link-args`: a version script given in
  `:link-args` limits the `.so`'s exports
- **Port sites:** `libs/nucdemo/build.edn`
- **Workaround:** none needed after the fix.

Context: `build.md` says `:link-args` are "passed to the link", and they are for a
program, but the `:shared true` edge of a library built its `clang -shared` line
without them, silently. So a library had no way to pass a version script, which is
the only way to stop ISSUE-049. The fix adds them to that line.

## ISSUE-050: In a file with no `(ns …)`, a macro can't name the file's own private helpers

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-050.nuc` — expected `7`; actual `macro 'twice' names 'helper',
  which is private to its file`
- **Port sites:** `libs/nucdemo` (`defn-stat` over `check-stats`), `tests/unit/main.nuc`
  (`check-format` over `formatted`)
- **Workaround:** give the file an `(ns …)`, with `(set-ir-prefix "")` where a C name
  must survive (`luaopen_nucdemo`, `main`).

Context: a template names what its file defines by full name, so that it expands the
same in another file; a private name in a file without a namespace has no full name,
so the macro is refused where it is written (`docs/macros.md`, "Public names only").
The rule is documented and the message says what to do. But both sites are a macro
used only in its own file, the commonest kind in a library or a test program, and
neither file needed a namespace for anything else. Refusing only an expansion in
another file would keep the guarantee without the cost.

## ISSUE-024: A `_`-prefixed macro isn't imported, even ISO C's `_IOFBF`

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Port sites:** `f_setvbuf` (`_IONBF`, `_IOFBF`, `_IOLBF`)
- **Workaround:** glibc's values, 2, 0 and 1, written out in `iolib.nuc`.

Context: the importer treats every name starting with `_` as the implementation's own
and leaves it out unless the import is `unsafe/import-private`. ISO C gives a few public
names that spelling: `setvbuf`'s three modes, `_Exit`, `_Bool`. Opting in pulls in every
private name of the header to reach three constants.

## ISSUE-025: `sizeof` is a signed integer, so comparing a size with it is refused

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Port sites:** `str_pack`'s `Kstring` case
- **Workaround:** compare with a constant (`SZINT`), or bind `(sizeof T)` to a `usize` first,
  which converts.

Context: `(>= size (sizeof lua_Unsigned))` with `size:usize` stops with `>=: mixed
signed/unsigned operands`. `sizeof` yields `ptr-int-type`, which is `i64` on this
target; the docs call it "a pointer-sized integer (size_t)", meaning its width. C's
`sizeof` is `size_t`, so every size comparison translated from C meets this. Making it
`usize` would change every `(* n (sizeof T))` over a signed `n` in existing code.

## ISSUE-026: A declaration with an attribute between its return type and its name was skipped

- **Severity:** blocker
- **Kind:** bug
- **Status:** fixed in nucleus `f282cfe`
- **Probe:** `probes/issue-026.nuc`
- **Port sites:** every call into `ldebug.h`'s and `ldo.h`'s error functions, starting
  with `lmem`'s `luaG_runerror` and `luaD_throw`

Context: `llimits.h` defines `l_noret` as `void __attribute__((noreturn))`, so
`LUAI_FUNC l_noret luaG_runerror (lua_State *L, const char *fmt, ...);` puts the
attribute after the return type. GCC admits it there, and the importer skipped the
declaration as "a declaration shape the C header parser does not recognize": it read
`__attribute__` as the name. It already skipped attributes before a declaration and
after its parameters. No module of the core can raise an error without this.

## ISSUE-027: Unary minus on a float is `0 - x`, so `(- 0.0)` is `0.0`, not `-0.0`

- **Severity:** major
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-027.nuc`
- **Port sites:** `numarith`'s `LUA_OPUNM` in `lobject.nuc`
- **Workaround:** `(* -1.0 x)`, which is exact and flips the sign of a zero.

Context: `lib/nucleus/macros.nuc` expands `(- x)` to `(_- 0 x)`. For an integer that is
negation, but IEEE subtraction from zero isn't: `0.0 - 0.0` is `+0.0`, where C's `-x`
gives `-0.0`. Lua prints `-(0.0)` as `-0.0`, and `1/(-0.0)` is `-inf`, so a port that
writes `(- x)` for `luai_numunm` is silently wrong. A fix needs a unary form the
operator can lower to `fneg`, which `node-type` must model too; the macro can't tell
`(- x)` from `(- 0 x)` once expanded.

## ISSUE-028: `bit-not` of an unsigned operand is refused

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-028.nuc`
- **Workaround:** `bit-xor` with the type's all-ones literal (`0xFFFFFFFF`), or `bit-not`
  on a signed value and a cast.

Context: `bit-not` is `(_bit-xor x -1)`, and a literal that doesn't fit its partner's
type is an error, so every unsigned operand fails with `integer literal -1 does not fit
ui32`. (`(bit-and a b c)`, whose fold identity is also `-1`, works: the identity is
never an operand.) C converts the `-1`; a fix needs either a `_bit-not`
primitive or a rule letting a negative literal mean its two's complement in a bitwise
operator.

## ISSUE-029: A constant macro built with a function-like macro isn't imported: `LUA_VNUMINT`

- **Severity:** minor
- **Kind:** known-limitation
- **Status:** worked-around
- **Port sites:** every variant tag (`lobject.h`), `MAX_LMEM`, `MAX_SIZE` (`llimits.h`),
  `CIST_FRESH` to `CIST_FIN` (`lstate.h`)
- **Workaround:** `defconst`s in `src/lua/core.nuc`, with the value written out.

Context: `#define LUA_VNUMINT makevariant(LUA_TNUMBER, 0)` is skipped as "a macro whose
body does not fold to an integer constant", though `makevariant(t,v)` is `((t) | ((v) <<
4))` and both arguments are constants. The importer folds an object-like macro's body
only when it's literal arithmetic over other such macros, so the twenty variant tags of
the core's type system have to be copied by hand, and a change to `lobject.h` would not
reach them.

## ISSUE-030: A `defconst` over a header constant is refused once a `defstruct` uses it as an array length

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-030.nuc`
- **Port sites:** `BuffFS` in `lobject.nuc` (`BUFVFS`)
- **Workaround:** the value written out, 219.

Context: `(defconst X LUA_IDSIZE)` folds to 60, and `(defconst BUFVFS (+ LUA_IDSIZE
LUA_N2SBUFFSZ 95))` to 219, until a `(defstruct S … b:(array i8 X))` names it. Then the
`defconst` itself is refused: "needs a run-time initializer; a constant's value must be
known at compile time -- use defvar". The struct's layout is presumably resolved in a
prescan that sees the constant before the header's constants are in, as with ISSUE-003,
and the message blames the `defconst`, not the struct that triggered it.

## ISSUE-031: A row of a header's 2-D array field doesn't decay, so it can't be indexed

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-031.nuc`
- **Port sites:** `global_State.strcache` in `string.nuc` (`luaS_new`, `luaS_init`,
  `luaS_clearcache`)
- **Workaround:** `strcache-row` in `core.nuc`: the row's address, `unsafe/cast` to a
  pointer to its element, as C's `TString **p = g->strcache[i]`.

Context: `TString *strcache[STRCACHE_N][STRCACHE_M]` imports, and `(g 'strcache)` decays
to `&(array (ptr TString) 2)`. `(aref (g 'strcache) i)` is then an `(array (ptr TString)
2)` *value*, which `aref` refuses ("operand must be typed pointer"). Nucleus's own
diagnostic says an array "decays to &T when it is read", and a field does, but an element
of an array of arrays doesn't. `as` from `&(array T 2)` to `&T` is refused as a
reinterpretation, so the workaround needs `unsafe/cast`. Nucleus can't declare an array
of arrays itself, so only an imported type reaches this.

## ISSUE-032: A store to a field of a union member was refused as a temporary

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `1ae171b`
- **Probe:** `probes/issue-032.nuc`
- **Port sites:** `UpVal`'s `u.open` in `func.nuc`; `ltable`'s `Node` (a union whose
  `u` is a struct) and `lgc`'s upvalue lists would have followed

Context: `(set! (((uv 'u) 'open) 'next) n)`, C's `uv->u.open.next = n`, failed with
"the receiver is a temporary struct value, so it has no address", for an imported union
and a Nucleus `(union …)` alike. The docs say a field of a pointee has storage, and
`(set! ((x 's) 'c) 5)` through a struct member works. The compiler's place typing
followed fields through structs only, so a union member's field was emitted as a value.
`((ref ((uv 'u) 'open)) 'next)` worked around it, but `Node` is written that way
throughout `ltable.c`, so it was fixed instead.

## ISSUE-033: A compilation could hold at most 256 macros

- **Severity:** blocker
- **Kind:** bug
- **Status:** fixed in nucleus `1ae171b`
- **Probe:** `nucleus` test `s21-many-macros` (in `1ae171b`): 300 macros
- **Port sites:** `lobject.nuc`, once `core.nuc` passed about 160 macros (`util.nuc`'s and
  the imported headers' count as well)

Context: the 257th `defmacro` in a compilation died with "defmacro: macro table full".
The core's macros are one per `lobject.h`/`lstate.h`/`lgc.h` macro, and the VM and the
parser need several hundred more, so no workaround (merging macros, splitting modules)
would have lasted. The cap guarded the fixed array of the compiler's original C
implementation; the table has been a growable vector since, so the check was simply
removed.

## ISSUE-034: In a namespaced file, a header type named like a prelude type is silently the prelude's

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-034.nuc`
- **Port sites:** `Node` (`lobject.h`'s hash node) in `table.nuc`, and `lgc`, `lvm` to come
- **Workaround:** a second, prefixed import, `(import "lobject.h" c)`, and `c/Node`
  wherever the type is named.

Context: `(import-use "lstate.h")` in a file with `(ns lua.table)` makes `Node` the
prelude's AST node (`nucleus/core.nuc`), so `((n 'u) 'next)` fails with "no field 'u'
on struct 'Node'", an error that names the right type and the wrong definition. Without
an `ns` the header's `Node` wins. The order is deliberate: a namespaced file probes its
own namespace, then its imported namespaces with the prelude among them, then `user`,
where a C header's types are registered, so "a user file's names never shadow the core
inside a library that imports a C header". A header type isn't a user file's name,
though, and nothing reports the collision. Ranking an explicitly imported header above
the prelude, or refusing the ambiguity, is a design decision.

## ISSUE-035: `unsafe/cast` from a function pointer to an integer is refused

- **Severity:** papercut
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-035.nuc`
- **Port sites:** `hashpointer` and `equalkey` in `table.nuc` (a light C function as a key)
- **Workaround:** through `ptr`: `(unsafe/cast usize (unsafe/cast ptr f))`.

Context: C's `point2uint(f)` hashes a `lua_CFunction` by its address. `(unsafe/cast usize
f)` fails with "cast: unsupported conversion", though `unsafe/cast` takes a function
pointer to `ptr` and `ptr` to `usize`, so the two-step spelling works. `as` from a function
pointer to `ptr` is refused as a reinterpretation, which is fair; the direct `unsafe/cast`,
whose contract is reinterpreting bits, has no reason to be.

## ISSUE-036: A `defvar`'s array initializer isn't macroexpanded before its shape is checked

- **Severity:** papercut
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-036.nuc`
- **Port sites:** `luaP_opmodes` in `opcodes.nuc`
- **Workaround:** the macro makes the whole `defvar`, which works at top level.

Context: `luaP_opmodes` is generated from the opcode rows by a macro expanding to an
`(array ui8 …)` literal, the shape the slot wants. `(defvar luaP_opmodes:(array ui8 85)
(with-opcodes opmodes-array))` is refused: "an (array ui8 85) slot must be initialized
with an (array T ...) literal". The check reads the initializer's syntax before any macro
in it expands, though the expansion is exactly the literal it asks for. A computed table,
which the docs recommend `macmap` and `~e` for, is the case it stops.

## ISSUE-037: A `defstruct` can't complete a struct its header declares without a body

- **Severity:** minor (papercut until M9)
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-037.nuc`
- **Port sites:** `Block` in `parser.nuc`; and the layouts as a whole, which stay in the
  stock internal headers (M9)
- **Workaround:** the struct takes another name, and the header's field is cast at
  each read and store (`fs-bl`).

Context: `lparser.h` declares `struct BlockCnt;` and `FuncState` points to one;
`lparser.c` gives the body. In C the `.c` file completes the type. A Nucleus
`(defstruct BlockCnt …)` under `(set-ir-prefix "")` is refused: "BlockCnt links as
%BlockCnt, the LLVM type of BlockCnt — rename it". A module that ports a C file
which owns such a struct needs a second name and casts at the boundary.

M9 was to move the layouts from `lobject.h`, `lstate.h` and the rest into
`defstruct`s once no C shared them. `lua.h` declares `lua_State` without a body,
and every API function's prototype names it, so the port's own `lua_State` would be
a second name, `State`, cast from `lua_State*` at each of the 180 API entry points,
in every hook and every `lua_CFunction` call, the `fs-bl` workaround multiplied by a
hundred. The port therefore still reads its layouts from the stock headers, as it did
during the migration; only the names moved (the `luaH_`, `luaV_` functions are
`table-`, `vm-` and so on). Letting a `defstruct` complete a header's declared
struct, as C's `.c` file does, is the one change that would free the layouts.

## ISSUE-038: A parameter named like a special form is accepted, then misparsed at its use

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-038.nuc`
- **Port sites:** `closegoto` (`label` is `lb`), `fieldexp` (C's `field`), `condexp`
  (C's `cond`) in `parser.nuc`
- **Workaround:** rename.

Context: `lparser.c` has a function `field` and a parameter `label`. `(defn- field …)`
is refused at once, plainly: "'field' already names a special form". But
`(defn closegoto (… label:(ptr Labeldesc) …) … (label 'pc))` is accepted at the
parameter and fails at the use: "label: name must be symbol", which names neither
the binding nor the conflict. A binding that can't be used should be refused where
it is made, with the first message.

## ISSUE-040: A later declarator in a field list imported as a bare `ptr`

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed in nucleus `a64ac73`
- **Probe:** `probes/issue-040.nuc` — expected `5`; actual `set!: operand must be a
  struct or union, or a pointer to one`
- **Port sites:** every walk of the CallInfo list: `luaE_extendCI`, `luaE_shrinkCI`
  in `state.nuc`, then `ldo` and `ldebug`
- **Workaround:** a typed `let` or `unsafe/cast` at each use of `next` or `previous`;
  fixed instead, since every CallInfo walk in `ldo` and `ldebug` would need one.

Context: `lstate.h` declares `struct CallInfo *previous, *next;`. `previous` imported
as a pointer to `CallInfo` and `next` as a bare `ptr`, so `((ci 'next) 'previous)`
was refused. The importer's declarator-list support assumed the first declarator's
`*` consumed the base type, which held before typed C pointers; the base is kept now,
and the later declarator lost it only because the parser didn't look. The layout was
always right, so nothing failed silently. `int *p, q;` was refused outright for the
same reason, though the type is plain.

## ISSUE-041: `bit-not` of an unsigned value is refused

- **Severity:** papercut
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-041.nuc` — expected `4286578687`; actual `integer literal -1
  does not fit ui32`
- **Port sites:** `luaG_traceexec` in `debug.nuc`, and every `ci->callstatus &= ~CIST_…`
  in `ldo`
- **Workaround:** `clearbits` in `util.nuc` widens the mask to `i64`, complements it and
  casts back.

Context: `bit-not` is a prelude macro, `(_bit-xor x -1)`, documented as "correct at
any width in two's complement". The literal `-1` takes the other operand's type, and
no unsigned type holds it, so C's `x & ~m` on an `l_uint32` doesn't compile. An
all-ones literal of the operand's type, or `(- 0 1)` in it, would do.

## ISSUE-042: `=` on two `CStr`s compares contents, so a C pointer test reads through null

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-042.nuc` — expected `different`; actual a crash in `strcmp`
- **Port sites:** `isEnv` in `debug.nuc`
- **Workaround:** compare `(as ptr …)` where C compares pointers.

Context: `ldebug.c` returns `strlocal` or `strupval` and tests the result by identity:
`what != strlocal && what != strupval`, with `what` possibly `NULL`. Ported as
written, `!=` on two `CStr`s is a `strcmp` (`docs/types.md`); only a literal `null`
operand gets a pointer test, so a null held in a variable crashed the suite in
`errors.lua`, `db.lua`, `math.lua` and `big.lua`, wherever an error named a field of
a global table. Content equality is a fair default for strings, but the same
spelling means identity on every other pointer, and nothing marks the difference at
a comparison of two variables. A null operand could at least compare unequal.

## ISSUE-043: A place under a macro call gave the address of a copy

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `275b612`, `d2c75f7`
- **Probe:** `probes/issue-043.nuc` — expected `same`; actual `different`
- **Port sites:** `mainthread` in `state.nuc` and `do.nuc`: `lua_yieldk`, `luaD_throw`,
  `lua_close`
- **Workaround:** bind `(G L)` to a name first; fixed instead, since nothing flags the
  copy and every macro that wraps a field path is exposed.

Context: `lstate.h` defines `mainthread(G)` as `&(G)->mainth.l`, ported as
`(ref ((~g 'mainth) 'l))`. Called as `(mainthread (G L))`, with `G` itself a macro,
the address was a stack slot: the typing pass leaves a macro call untyped, so the
receiver `((G L) 'mainth)` was emitted as a struct value and stored in a temporary.
With a named `g`, as in `lua_newstate`, it was right, so the port ran until
`errors.lua` asked `coroutine.yield()` outside a coroutine and got "attempt to yield
across a C-call boundary": `lua_yieldk` never saw the main thread. A `set!` one level
deeper was refused as a temporary receiver, which at least was loud.
`d2c75f7` covers the next step, an element of an array field under a macro call:
`lua_setiuservalue`'s `&uvalue(o)->uv[n-1].uv` stored into a copy, and the C API
matrix caught it.

## ISSUE-044: A global `i8` array takes no string initializer

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-044.nuc` — expected `abc`; actual `an (array i8 4) slot must
  be initialized with an (array T ...) literal`
- **Port sites:** `lua_ident` in `api.nuc`
- **Workaround:** the `defident` macro reads the string literal's bytes and writes the
  `defvar` with an `(array i8 ...)` of them.

Context: `lapi.c` exports `const char lua_ident[]`, a C string whose size is part of
its type. A `CStr` global would be a pointer, which a C caller's `extern const char
lua_ident[]` would read as bytes of an address. The macro works, but a string literal
filling an `i8` array, sized from it when the length is left out, is what C programs
expect of a byte array.

## ISSUE-039: A `build.edn` makes one program, and a second sharing its sources warns at every build

- **Severity:** papercut
- **Kind:** tooling
- **Status:** worked-around
- **Probe:** `probes/issue-039.nuc` — expected no warning; actual one per path that
  leaves the project
- **Port sites:** `luac/build.edn`
- **Workaround:** `luac` is its own project under `luac/`, whose `:entry` and
  `:source-root` climb to the port's (as its `:c-sources` did until M7); the warnings
  are ignored.

Context: Lua builds two programs, `lua` and `luac`, from one core. `build.edn` has one
`:entry` and one `:name`, and a target can't set either, so a second program needs a
second project. Sharing the first one's sources is then exactly the path the tool
warns about ("is outside the project … a local path belongs in build-local.edn"),
although the path is committed and holds in every checkout. The alternative, the core
as a `:kind :library`, archives it, so `lua` would need `--whole-archive` to keep the
API symbols that C modules call. A `:programs` map (name to entry), sharing the rest
of the settings, would cover both.

## ISSUE-051: A local named like a macro in scope is the macro at the head of a form

- **Severity:** minor
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-051.nuc` — expected `5`; actual `quote needs the node
  runtime — add (import-use nucleus.node)`
- **Port sites:** `state-shrink-ci` in `state.nuc` and the upvalue list in `func.nuc`
  (a local `next`), once M9's imports made `lex.nuc`'s `next` macro visible there
- **Workaround:** rename the macro (`next-char`); the core's shared macros got names
  no local would take (`exp-u`, not `u`).

Context: `(x 'f)` is how Nucleus reads a field through a pointer, so a local in head
position is ordinary: `next:(ptr CallInfo)` then `(next 'next)`. If any macro named
`next` is in scope, from any imported module, the form is a macro call instead, and
the error is about the expansion, here a quoted symbol that the macro body spliced
into code. Nothing says the binding was shadowed. A local should shadow a macro in
its scope, as it shadows a function; at the least, the binding should be refused
where it is made, as ISSUE-038 asks for special forms. A module's public macros are
every importer's reserved words, so the risk grows with each `import-use`.

## ISSUE-052: A macro doesn't cross an import cycle

- **Severity:** minor
- **Kind:** known-limitation
- **Status:** worked-around
- **Port sites:** the core's modules, which call one another in cycles (`ldo` raises
  through `ldebug`, which calls `ldo`); 34 macros that a second module used, from
  `mainthread` to `exp-u`
- **Workaround:** every macro a second module uses lives in `core.nuc`, which
  imports no other core module.

Context: until M9 the core's functions kept their C names, so the stock headers
declared them and every module reached every other without importing it. Renamed,
they need imports, and the core's imports form cycles. The docs say cycles are legal
and carry functions, globals and constants, but not macros: "unknown: set-u —
defined in a file this unit imports circularly". The rule moves each shared macro to
a leaf, away from the structure it belongs to, `code.nuc`'s `expdesc` accessors
included. It did also expose 17 macros the migration had copied into two to four
modules each, some subtly different (`pcRel`, `get_nresults`, `tonumber`'s result
type); they are one copy each now. A macro registered graph-wide, as signatures
are, would keep each where it is defined. The same message also stands for a plain
missing import: a function whose module the file never imported was reported as
"defined in a file this unit imports circularly, and not registered yet".

## ISSUE-053: Under `(set-ir-prefix "")`, two namespaces can't each have a private helper of one name

- **Severity:** papercut
- **Kind:** design
- **Status:** worked-around
- **Probe:** `probes/issue-053.nuc` — expected `1 2`; actual `duplicate definition of
  'helper' … both definitions are in namespace 'b'`
- **Port sites:** `tests/T/src/lua/tests.nuc`, whose `resetCI` met `state.nuc`'s
  private `reset-ci`
- **Workaround:** rename one (`free-cis`).

Context: the port keeps C's link names with `(set-ir-prefix "")`, so a `defn-` in two
namespaces is one IR symbol. Refusing that is fair, as two `static` functions of one
name are fine in C only because each has internal linkage. Here a private function
could have internal linkage too and keep its bare name; failing that, the message
should name both namespaces, not say both are in the second.

## ISSUE-054: A string-path import isn't looked up beside the importing file

- **Severity:** papercut
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-054.nuc` — expected `8`; actual `import: cannot find
  'z.nuc'` when compiled from another directory
- **Port sites:** `tests/T/src/tmain.nuc`, whose `"../../src/main.nuc"` is relative to
  `tests/T`, where `nucleus build` runs, not to `tests/T/src`
- **Workaround:** write the path relative to the build directory.

Context: docs/toplevel.md, "Where an import is found", puts "the directory of the file
that holds the import" first, for a library name or a `.nuc` string path. A library
name is found there; a string path is resolved against the current directory only.
The same source then means different files depending on where the compiler starts.

## ISSUE-055: `<` on two pointers is a signed comparison

- **Severity:** minor
- **Kind:** bug
- **Status:** open
- **Probe:** `probes/issue-055.nuc` — expected `1`; actual `0`: `0x7fff…ffff < 0x8000…0000`
  is false
- **Port sites:** every pointer comparison: the matcher's `s < src_end`, the stack's
  `top < stack_last`, the lexer's and the dumper's buffer ends
- **Workaround:** none needed here: x86-64 Linux user addresses are below 2^47.

Context: the emitter writes `icmp slt ptr` for `<` on pointers; C compares them
unsigned. Found reading `singlematch`'s assembly beside clang's (`jle` for `jbe`). On
a 32-bit target, where the stack and the heap straddle 2^31, or on AVR, which Nucleus
targets, the port's bound checks would invert. Pointers should take `ult`/`ule`.

## ISSUE-056: glibc's `isalpha` is a macro over a table lookup, and the import calls the function

- **Severity:** minor
- **Kind:** interop
- **Status:** open
- **Probe:** `probes/issue-056.nuc` — expected no `call i32 @isalpha` in the IR; actual one
- **Port sites:** `match-class` in `strlib.nuc` (`tolower`, `isalpha`, `islower`, … per
  character matched); `lctype` has its own table, so the lexer is unaffected
- **Workaround:** none taken; the fix in the port would read glibc's private
  `__ctype_b_loc` table, which ISSUE-018 already does too much of.

Context: `ctype.h` declares `isalpha` and, under `__OPTIMIZE__`, defines a macro and an
inline `tolower` over `__ctype_b_loc()`. The import keeps the declaration and drops the
macro, so each call is a PLT call into libc. Nothing warns: the code is right and
slower. `patterns` runs at 1.21 times stock built by clang with LTO; stock built with
`-D__NO_CTYPE`, so that it makes the same calls, recovers a third of that (half of
`gmatch`'s). A function-like macro that shadows a function is the case ISSUE-018's
fix would have to choose: the macro, as C does.

## ISSUE-057: No branch hint, so rare paths stay inline

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** open
- **Port sites:** `vm.nuc`'s `vmbreak` (the hook trap after every opcode) and every
  `l_likely`/`l_unlikely` of the C (51 in the core, 114 in all), written as plain tests
- **Workaround:** none.

Context: C's `l_unlikely` is `__builtin_expect`; Nucleus has neither an expectation
nor a `cold` attribute (`fn-attr` takes string attributes only, and `cold` is an enum
one). The cost measured is code size: stock built without the hints grows
`luaV_execute` from 21.6 KB to 26.0 KB, the port's size, with no speed change outside
noise. A `(likely c)` form lowering to `llvm.expect`, or a `:cold` attribute, would
keep the VM's error and hook paths out of its hot loop.

## What worked well

- `(import-use "lua.h")`, once ISSUE-002 was fixed: every type, function and
  constant, `LUA_REGISTRYINDEX` included, with `luaL_Buffer` at 1056 bytes and
  alignment 16 straight from the header.
- The binding's macros are `defmacro`s, so a library built on it exports none
  of them and needs no runtime of its own.
- `defn-lua` turns a parameter list into C's argument checks:
  `(defn-lua c-inc (L (c (udata Counter "idiom.Counter")) (by integer 1)) …)` binds
  `c:&Counter` through `luaL_checkudata` and `by` through `luaL_optinteger`, where C
  writes both calls and a cast by hand. `deflualib` builds `luaopen_` and each
  userdata metatable from one form, so the function table can't fall out of step.
- The layout gate came out right first time: 112 sizes, offsets and constants of
  the public structs, `luaL_Buffer`'s 16-byte `long double` alignment included.
- One opcode row set (`with-opcodes`) makes both `luaP_opmodes` and `luac`'s
  `opnames`: a macro walks the rows and strips `OP_` from each name, so C's three
  hand-kept lists (`lopcodes.h`, `lopcodes.c`, `lopnames.h`) are one.
- `!T` fits `luac`'s option parser (PROMPT §9): it is self-contained, so `doargs`
  returns `(Result i32 CStr)`, the first file's index or what `usage` should say,
  and only `main` exits. A throw that crosses Lua's frames still needs `longjmp`.
