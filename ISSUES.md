# Findings

Ranked by porter pain removed per unit of language work.

| Rank | Issue | Claim | Severity | Kind | Status |
|---|---|---|---|---|---|
| 1 | ISSUE-005 | A library's public `defn` is preempted by any same-named symbol in the process | major | design | open |
| 2 | ISSUE-023 | An array field of a nested place decayed to a copy's address, losing every store | major | bug | fixed in nucleus `0081d2a` |
| 3 | ISSUE-032 | A store to a field of a union member was refused as a temporary | major | bug | fixed in nucleus `1ae171b` |
| 4 | ISSUE-043 | A place under a macro call, `&G(L)->mainth.l`, gave the address of a copy | major | bug | fixed in nucleus `275b612` |
| 5 | ISSUE-033 | A compilation could hold at most 256 macros | blocker | bug | fixed in nucleus `1ae171b` |
| 6 | ISSUE-026 | A declaration with an attribute between its return type and its name was skipped | blocker | bug | fixed in nucleus `f282cfe` |
| 7 | ISSUE-022 | A definition that misses its header's prototype silently becomes a mangled overload | major | design | worked-around |
| 8 | ISSUE-004 | A function's address isn't a constant in an aggregate initializer | major | missing-feature | worked-around |
| 9 | ISSUE-013 | An imported file can't define a function its header declares | blocker | bug | fixed in nucleus `5dab7cb` |
| 10 | ISSUE-001 | A C variadic couldn't be defined in Nucleus | major | known-limitation | fixed in nucleus `336a93b` |
| 11 | ISSUE-002 | `RET (name)(args)`, how Lua declares every function, was skipped by a header import | blocker | known-limitation | fixed in nucleus `beb0472` |
| 12 | ISSUE-006 | Calling a C variadic by `declare` passed the tail unpromoted, with `%al` unset | major | bug | fixed in nucleus `cd516e6` |
| 13 | ISSUE-003 | A `defvar` array of a header's struct was refused as opaque | major | bug | fixed in nucleus `beb0472` |
| 14 | ISSUE-008 | Integer to float takes `unsafe/cast` | major | design | worked-around |
| 15 | ISSUE-027 | Unary minus on a float is `0 - x`, so `(- 0.0)` is `0.0`, not `-0.0` | major | bug | worked-around |
| 16 | ISSUE-019 | A header's `char *` is `(ptr i8)`, and an `if` won't join it with a string literal | minor | design | worked-around |
| 17 | ISSUE-021 | Pointers can't be subtracted | minor | missing-feature | worked-around |
| 18 | ISSUE-028 | `bit-not` of an unsigned operand is refused | minor | bug | worked-around |
| 19 | ISSUE-029 | A constant macro built with a function-like macro isn't imported: `LUA_VNUMINT` | minor | known-limitation | worked-around |
| 20 | ISSUE-030 | A `defconst` over a header constant is refused once a `defstruct` uses it as an array length | minor | bug | worked-around |
| 21 | ISSUE-031 | A row of a header's 2-D array field doesn't decay, so it can't be indexed | minor | bug | worked-around |
| 22 | ISSUE-034 | In a namespaced file, a header type named like a prelude type is silently the prelude's | minor | design | worked-around |
| 23 | ISSUE-018 | A header's expression macros aren't imported: `errno`, `WIFEXITED` | minor | known-limitation | worked-around |
| 24 | ISSUE-007 | A shared library is always named `lib<name>.so` | minor | tooling | worked-around |
| 25 | ISSUE-010 | There is no `offsetof` | minor | missing-feature | worked-around |
| 26 | ISSUE-012 | A header's string macros aren't imported | minor | known-limitation | worked-around |
| 27 | ISSUE-011 | No `sizeof` of an expression, so no array length | minor | missing-feature | worked-around |
| 28 | ISSUE-015 | Only the entry file can export a strong symbol | minor | design | worked-around |
| 29 | ISSUE-016 | No byte literal: `\e` is a 32-bit Char and won't convert to `i8` | minor | design | worked-around |
| 30 | ISSUE-017 | A `CStr` can't be indexed | minor | design | worked-around |
| 31 | ISSUE-014 | `SIG_DFL` imports as the integer 0 | minor | interop | worked-around |
| 32 | ISSUE-040 | A later declarator in a field list (`*previous, *next`) imported as a bare `ptr` | minor | bug | fixed in nucleus `a64ac73` |
| 33 | ISSUE-042 | `=` on two `CStr`s compares contents, so a C pointer test ported as written reads through null | minor | design | worked-around |
| 34 | ISSUE-041 | `bit-not` of an unsigned value is refused: `-1` doesn't fit it | papercut | bug | worked-around |
| 35 | ISSUE-024 | A `_`-prefixed macro isn't imported, even ISO C's `_IOFBF` | papercut | design | worked-around |
| 36 | ISSUE-020 | `set!` won't expand a macro in its place | papercut | missing-feature | worked-around |
| 37 | ISSUE-025 | `sizeof` is a signed integer, so comparing a size with it is refused | papercut | design | worked-around |
| 38 | ISSUE-035 | `unsafe/cast` from a function pointer to an integer is refused | papercut | bug | worked-around |
| 39 | ISSUE-036 | A `defvar`'s array initializer isn't macroexpanded before its shape is checked | papercut | bug | worked-around |
| 40 | ISSUE-037 | A `defstruct` can't complete a struct its header declares without a body | papercut | missing-feature | worked-around |
| 41 | ISSUE-038 | A parameter named like a special form is accepted, then misparsed at its use | papercut | design | worked-around |
| 42 | ISSUE-039 | A `build.edn` makes one program, and a second sharing its sources warns at every build | papercut | tooling | worked-around |
| 43 | ISSUE-009 | A library's diagnostics print three times | papercut | tooling | open |

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
export list and no `-fvisibility=hidden`/`-Bsymbolic` switch.

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

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Probe:** `probes/issue-037.nuc`
- **Port sites:** `Block` in `parser.nuc`
- **Workaround:** the struct takes another name, and the header's field is cast at
  each read and store (`fs-bl`).

Context: `lparser.h` declares `struct BlockCnt;` and `FuncState` points to one;
`lparser.c` gives the body. In C the `.c` file completes the type. A Nucleus
`(defstruct BlockCnt …)` under `(set-ir-prefix "")` is refused: "BlockCnt links as
%BlockCnt, the LLVM type of BlockCnt — rename it". A module that ports a C file
which owns such a struct needs a second name and casts at the boundary.

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
- **Status:** fixed in nucleus `275b612`
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

## ISSUE-039: A `build.edn` makes one program, and a second sharing its sources warns at every build

- **Severity:** papercut
- **Kind:** tooling
- **Status:** worked-around
- **Probe:** `probes/issue-039.nuc` — expected no warning; actual one per path that
  leaves the project
- **Port sites:** `luac/build.edn`
- **Workaround:** `luac` is its own project under `luac/`, whose `:entry`,
  `:source-root` and `:c-sources` climb to the port's; the eight warnings are ignored.

Context: Lua builds two programs, `lua` and `luac`, from one core. `build.edn` has one
`:entry` and one `:name`, and a target can't set either, so a second program needs a
second project. Sharing the first one's sources is then exactly the path the tool
warns about ("is outside the project … a local path belongs in build-local.edn"),
although the path is committed and holds in every checkout. The alternative, the core
as a `:kind :library`, archives it, so `lua` would need `--whole-archive` to keep the
API symbols that C modules call. A `:programs` map (name to entry), sharing the rest
of the settings, would cover both.

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
