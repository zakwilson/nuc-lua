# Findings

Ranked by porter pain removed per unit of language work.

| Rank | Issue | Claim | Severity | Kind | Status |
|---|---|---|---|---|---|
| 1 | ISSUE-005 | A library's public `defn` is preempted by any same-named symbol in the process | major | design | open |
| 2 | ISSUE-004 | A function's address isn't a constant in an aggregate initializer | major | missing-feature | worked-around |
| 3 | ISSUE-001 | A C variadic couldn't be defined in Nucleus | major | known-limitation | fixed in nucleus `336a93b` |
| 4 | ISSUE-002 | `RET (name)(args)`, how Lua declares every function, was silently dropped from a header import | blocker | bug | fixed in nucleus (pending) |
| 5 | ISSUE-006 | Calling a C variadic by `declare` passed the tail unpromoted, with `%al` unset | major | bug | fixed in nucleus `cd516e6` |
| 6 | ISSUE-003 | A `defvar` array of a header's struct was refused as opaque | major | bug | fixed in nucleus (pending) |
| 7 | ISSUE-007 | A shared library is always named `lib<name>.so` | minor | tooling | worked-around |

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

## ISSUE-002: `RET (name)(args)` was silently dropped from a header import

- **Severity:** blocker
- **Kind:** bug
- **Status:** fixed in nucleus (pending commit)
- **Probe:** `probes/issue-002.nuc` — expected `42`; actual `error: unknown: twice`
- **Port sites:** every function in `lua.h`, `lauxlib.h` and `lualib.h`
- **Workaround:** none; it was fixed.

Context: Lua declares `LUA_API int (lua_gettop) (lua_State *L);` so that a
function-like macro of the same name can't expand there. The importer read a `(`
after the return type as a function-pointer declarator, found no `*`, and gave
up with no diagnostic, so `(import-use "lua.h")` brought in the types and
constants and none of the functions. The first symptom was `unknown:
lua_pushinteger`, which reads as a typo, not as a dropped declaration.

## ISSUE-003: A `defvar` array of a header's struct was refused as opaque

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus (pending commit)
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

## What worked well

- `(import-use "lua.h")`, once ISSUE-002 was fixed: every type, function and
  constant, `LUA_REGISTRYINDEX` included, with `luaL_Buffer` at 1056 bytes and
  alignment 16 straight from the header.
- The binding's 60 macros are `defmacro`s, so a library built on it exports none
  of them and needs no runtime of its own.
