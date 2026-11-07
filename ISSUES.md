# Findings

Ranked by porter pain removed per unit of language work.

| Rank | Issue | Claim | Severity | Kind | Status |
|---|---|---|---|---|---|
| 1 | ISSUE-005 | A library's public `defn` is preempted by any same-named symbol in the process | major | design | open |
| 2 | ISSUE-023 | An array field of a nested place decayed to a copy's address, losing every store | major | bug | fixed in nucleus `0081d2a` |
| 3 | ISSUE-022 | A definition that misses its header's prototype silently becomes a mangled overload | major | design | worked-around |
| 4 | ISSUE-004 | A function's address isn't a constant in an aggregate initializer | major | missing-feature | worked-around |
| 5 | ISSUE-013 | An imported file can't define a function its header declares | blocker | bug | fixed in nucleus `5dab7cb` |
| 6 | ISSUE-001 | A C variadic couldn't be defined in Nucleus | major | known-limitation | fixed in nucleus `336a93b` |
| 7 | ISSUE-002 | `RET (name)(args)`, how Lua declares every function, was skipped by a header import | blocker | known-limitation | fixed in nucleus `beb0472` |
| 8 | ISSUE-006 | Calling a C variadic by `declare` passed the tail unpromoted, with `%al` unset | major | bug | fixed in nucleus `cd516e6` |
| 9 | ISSUE-003 | A `defvar` array of a header's struct was refused as opaque | major | bug | fixed in nucleus `beb0472` |
| 10 | ISSUE-008 | Integer to float takes `unsafe/cast` | major | design | worked-around |
| 11 | ISSUE-019 | A header's `char *` is `(ptr i8)`, and an `if` won't join it with a string literal | minor | design | worked-around |
| 12 | ISSUE-021 | Pointers can't be subtracted | minor | missing-feature | worked-around |
| 13 | ISSUE-018 | A header's expression macros aren't imported: `errno`, `WIFEXITED` | minor | known-limitation | worked-around |
| 14 | ISSUE-007 | A shared library is always named `lib<name>.so` | minor | tooling | worked-around |
| 15 | ISSUE-010 | There is no `offsetof` | minor | missing-feature | worked-around |
| 16 | ISSUE-012 | A header's string macros aren't imported | minor | known-limitation | worked-around |
| 17 | ISSUE-011 | No `sizeof` of an expression, so no array length | minor | missing-feature | worked-around |
| 18 | ISSUE-015 | Only the entry file can export a strong symbol | minor | design | worked-around |
| 19 | ISSUE-016 | No byte literal: `\e` is a 32-bit Char and won't convert to `i8` | minor | design | worked-around |
| 20 | ISSUE-017 | A `CStr` can't be indexed | minor | design | worked-around |
| 21 | ISSUE-014 | `SIG_DFL` imports as the integer 0 | minor | interop | worked-around |
| 22 | ISSUE-024 | A `_`-prefixed macro isn't imported, even ISO C's `_IOFBF` | papercut | design | worked-around |
| 23 | ISSUE-020 | `set!` won't expand a macro in its place | papercut | missing-feature | worked-around |
| 24 | ISSUE-025 | `sizeof` is a signed integer, so comparing a size with it is refused | papercut | design | worked-around |
| 25 | ISSUE-009 | A library's diagnostics print three times | papercut | tooling | open |

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
- **Port sites:** `scripts/check-layout.sh`; Lua's `offsetof` uses (`lfunc.h`'s
  `sizeofCclosure`, `lstring.h`'s `sizelstring`, `ltable.c`) will follow
- **Workaround:** a global of the struct, and the field's address minus the
  struct's: `(- (unsafe/cast i64 (ref g 'f)) (unsafe/cast i64 &g))`

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
  function; every `cond x ? lua_tostring(...) : "literal"` in the libraries
- **Workaround:** `lua.util/cstr`, `(as CStr (as ptr p))`.

Context: a `const char *` parameter imports as `CStr`, but a return value or a struct
field of the same type imports as `(ptr i8)`. A `let` with a `CStr` slot accepts a
`(ptr i8)`, yet `(if c (lua_tostring L -1) "nil")` is refused: "value is either (ptr i8)
or CStr". C's `?:` with a string literal on one side is common in Lua's sources.

## ISSUE-020: `set!` won't expand a macro in its place

- **Severity:** papercut
- **Kind:** missing-feature
- **Status:** worked-around
- **Port sites:** `errno = 0` in `luaL_loadfilex` (3), `liolib.c`, `loslib.c`
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
