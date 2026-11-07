# Port Lua to Nucleus — a language stress test

## 1. Mission

Test the Nucleus (`../nucleus`) language and compiler by porting the Lua (`../lua-5.5.1`) interpreter from C to Nucleus.

**Producing a port is the secondary goal. The primary goal is to stress-test the
language: find missing or poorly designed features, and record them in `ISSUES.md`.**
A finished port with a thin `ISSUES.md` is a failed run. A partial port with a
precise, well-evidenced `ISSUES.md` is a useful one. When the two goals compete
for your time, the report wins.

One requirement is not negotiable, because it is where this port earns its keep:
**Lua code running in the port must be able to call libraries written in C
against the unmodified Lua API, as in the demo at `scratch/mayi.c`, and the same
kind of library must be writable in Nucleus.** §6 turns that into a contract.

Use Nucleus features to make the code shorter, easier to understand, or more
reliable than the C, including but not limited to:

* Macros, including `macrolet` and `macmap`
* Generics (multimethods, bounded generic `defn`, parametric structs)
* Protocols (including `(dyn P)` where runtime dispatch is genuinely needed)
* Compile-time evaluation
* Non-nullable refs (`&T`) and narrowed nullables (`?&T`)
* Error handling (`!T`, `deferror`, `try`, `match`)
* `Const` data literals (`[…]`, `{…}`, `#{…}`)
* The Nucleus standard library (collections, `String`/`StrView`, allocators, `fmt`, file I/O, test framework)

Improving Lua's semantics is not a goal. Matching Lua's speed is not a gate, but
speed is measured (§7.5), because a language for systems work has to be able to
express an interpreter's hot loop.

This port asks a different question from the two Doom ports. They showed that
Nucleus can *consume* C and hold a large single-threaded program together. Lua
asks whether Nucleus can be a language **runtime** and a first-class citizen on
**both sides of the C ABI**:

- defining an exact C ABI that foreign binaries link against, not just calling one;
- `dlopen` in both directions, with separately built libraries sharing a process;
- non-local exits (`setjmp`/`longjmp`) crossing Nucleus and C frames, and what
  that does to `with`/`drop` and `!T`;
- a tracing garbage collector over raw, type-punned object headers, flexible
  array members and write barriers;
- a dispatch function of about 800 lines with computed `goto`, where code
  generation quality is visible;
- the corners of integer and float semantics that a language spec pins down
  exactly (wraparound, shifts, float-to-int conversion, NaN, signed zero).

If a module ends up reading like C with parentheses, that is either a finding
(the idiomatic version was impossible or worse; say why) or a defect in the port.

## 2. The source

Lua 5.5.1 (`../lua-5.5.1`, MIT, released 2026-07-24) is about 32,200 lines of
C99, headers and comments included. The tree there matches the lua.org tarball
exactly. Stock Lua is built with `make linux` (`-DLUA_USE_LINUX`, `-Wl,-E -ldl`);
that configuration is the one to port.

| Layer | Files | What it does |
|---|---|---|
| Public API | `lua.h`, `lauxlib.h`, `lualib.h`, `luaconf.h`, `lapi.c` | The contract in §6 |
| Object model | `lobject`, `lstring`, `ltable`, `lfunc`, `ltm`, `lctype`, `lzio`, `lmem`, `llimits.h` | Tagged values, interned strings, tables, closures, metamethods |
| Compiler | `llex`, `lparser`, `lcode`, `lopcodes`, `ldump`, `lundump` | Source to register bytecode, and binary chunks |
| Runtime | `lvm`, `ldo`, `lstate`, `ldebug`, `lgc` | The interpreter loop, calls, errors and coroutines, per-thread state, debug info and hooks, the incremental and generational collector |
| Libraries | `lauxlib`, `lbaselib`, `lcorolib`, `ldblib`, `liolib`, `lmathlib`, `loadlib`, `loslib`, `lstrlib`, `ltablib`, `lutf8lib`, `linit` | Written against the public API (and so a template for §6's libraries) |
| Programs | `lua.c`, `luac.c` | The standalone interpreter, and the bytecode compiler and lister. `luac.c` reaches into internals; `lua.c` doesn't |

The official test suite isn't in `../lua-5.5.1`. It's a separate tarball,
`https://www.lua.org/tests/lua-5.5.1-tests.tar.gz` (sha256
`da07b543872dc0bb2ff12aabd0c248578d78df3eb6b67efdc537a46d455c7f31`): about
18,000 lines of Lua, the C test libraries in `libs/`, and `ltests/`, which holds
the internal test library behind the `T` table. The Lua source tarball is
`https://www.lua.org/ftp/lua-5.5.1.tar.gz` (sha256
`1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce`).

## 3. Ground rules

1. **Never modify `../lua-5.5.1`, or `scratch/mayi.c`.** Build the reference
   from a copy (§7.1). `scratch/mayi.c` is a fixed test input.
2. **You may fix bugs in Nucleus** (§8, "Fixing the compiler"). Everything else,
   including missing features and design problems, is recorded and worked
   around, not changed.
3. **No C in the finished port, with one tagged exception.** Stock C files may
   stay linked while the port is in progress (§9, the migration). At the end,
   the only C that may remain is `src/c/`, holding what Nucleus cannot express.
   Every function there names the ISSUE that forces it. Today that means the
   variadic entry points (§6.4). Don't grow this directory to save effort: if
   something could be Nucleus, it must be.
4. **Never discard work with git** (`git restore`, `git checkout <file>`,
   `git reset --hard`, `git clean`), in any repo. If the build breaks, fix the
   source.
5. **License.** Lua is MIT. Ship `LICENSE` with Lua's notice as it stands at the
   end of `lua.h`. Give each ported file a short header naming its source file
   and `Copyright (C) 1994-2026 Lua.org, PUC-Rio`.
6. **Commit at each milestone whose gates are green**, with a message that names
   the milestone and the new ISSUE ids, and commit smaller steps in between. This
   directory isn't a git repository yet: run `git init` in milestone 0. Push
   after each commit once a remote exists. Work on the branch the session names,
   if it names one.
7. **No subagents and no workflows.** Do all the work in the main thread. The
   harness resumes the main thread automatically when it hits a session limit,
   but a subagent that hits the limit is lost.
8. **The port must build on the user's machine and any other.** Nothing in
   `build.edn` or the scripts may hardcode a path. Every script gets its compiler
   from `scripts/env.sh`, and finds sibling checkouts relative to the repo.
9. **Don't overwrite a compiler you can't run.** `../nucleus/build/nucleusc` may
   have been built on another machine against another LLVM (as of this writing it
   wants `libLLVM.so.23.1`). If it won't start here, build in your own clone,
   such as `../nucleus-work`, and point `NUCLEUS_HOME` at that. Never rebuild over
   someone's working `build/`.

## 4. Required reading before writing port code

Read these Nucleus docs in full: `index.md`, `types.md`, `toplevel.md`,
`special-forms.md`, `structs-unions.md`, `generics.md`, `macros.md`,
`errors.md`, `collections.md`, `allocators.md`, `strings.md`, `iterators.md`,
`build.md` (all of it, including Library projects), and `testing.md`. In
`compiler.md`, read "Separate compilation and symbol linkage", "Hyphenated names
in a C header" through "Names C reserves", and "Integer constants from a C
header". Skim `builtins.md`, `stdlib.md`, `io.md`, and the rest of `compiler.md`,
and come back to them as needed. Then read `examples/` for idiom, especially
`setjmp-guard.nuc` and the `cheader-*` files: the examples are the closest thing
to a style guide.

Then read Lua's reference manual (`doc/manual.html`) §4 and §5 (the C API and the
auxiliary library) in full, then `lua.h`, `lauxlib.h`, `lobject.h`, `lstate.h`,
`ldo.c` and `lapi.c`. Read the rest of the C as you reach it.

Before you report a limitation, check whether it is already known. Look for
"Sharp edge", "Limits" and "not supported" in `docs/`, in `design/deferred/`,
`design/future/` and `design/doom-port-fixes/`, and in
`../nuc-iron-doom/ISSUES.md` (32 findings, several since fixed). A known
limitation that still hurts the port **is still a finding**: record it with
`Kind: known-limitation` and say what it cost, but never present it as a newly
discovered bug. A finding from the Doom ports that recurs here in a different
shape is worth recording. Cite its ISSUE id.

## 5. Scope

**In scope:**

- The whole core, every standard library, `lua.c` and `luac.c`, for the
  configuration `make linux` builds: `lua_Integer` is `long long`, `lua_Number`
  is `double`, and every default in `luaconf.h` stands.
- The C API contract in §6, including the Nucleus binding and example libraries.
- `dlopen`-based loading through `require` and `package.loadlib`.

**Out of scope:** Windows, macOS, AIX and the other `#ifdef` platforms, `LUA_USE_C89`,
`LUA_32BITS` and other `luaconf.h` variations (keep the code from being
gratuitously x86-64 Linux-specific, but don't add paths you can't test); the C++
exception variant of `LUAI_THROW`; `lua.hpp`; readline (the basic `fgets` REPL is
fine, though a `readline` build is welcome if it's cheap); changing language
semantics or the bytecode.

## 6. The C API contract

The port replaces `liblua` and the `lua` executable. A compiled third-party C
module cannot tell the difference.

### 6.1 Binary compatibility

- **The stock headers are the contract.** C modules compile against unmodified
  `lua.h`, `lauxlib.h`, `lualib.h` and `luaconf.h`. Commit them under `include/`,
  and make `check-capi.sh` fail if they differ from `../lua-5.5.1/src/`.
- **Compiled means compiled.** A `.so` built once with
  `gcc -shared -fPIC -I include mayi.c -o mayi.so` must load, unrebuilt, into both
  the stock `lua` and the port. It isn't linked against any `liblua`: its `lua_*`
  references resolve against the host executable at `dlopen` time.
- **Every public symbol exists.** Stock `lua` exports 157 Lua symbols: 99 `lua_*`
  (98 functions and the data symbol `lua_ident`), 48 `luaL_*` and 10 `luaopen_*`.
  The port's dynamic symbol table must define exactly the same set, with the same
  kinds, and `check-capi.sh` compares them. The linker's `--gc-sections` runs on
  every Nucleus link, so prove that an API function the port never calls survives.
- **`require` behaves as documented.** `package.cpath` and `package.path` have
  their stock defaults, `LUA_CPATH`/`LUA_PATH` (and the `_5_5` forms) work,
  `require "a.b"` finds `luaopen_a_b`, and hyphenated module names and
  `package.loadlib(path, "*")` work. As in stock Lua, `lua_close` unloads
  libraries through `dlclose`.

### 6.2 What the macros pin down

There are 60 function-like macros in `lua.h` and `lauxlib.h`, and compiled C
modules have them baked in. They fix parts of the layout that would otherwise be
private. Measure these with an `offsetof` test against the real headers, as a
gate. The sizes below were measured on stock x86-64 Linux:

| Thing | Why it's public | Must hold |
|---|---|---|
| `luaL_Buffer` | `luaL_addchar`, `luaL_addsize`, `luaL_buffsub` touch fields directly | size 1056, alignment 16 (`LUAI_MAXALIGN` includes `long double`), `init` at offset 32 |
| `lua_Debug` | Filled in for C callers | size 144, `short_src` at 76, `i_ci` at 136 |
| `luaL_Reg` | Static tables in every module | size 16, ended by `{NULL, NULL}` |
| `luaL_Stream` | Other libraries create `LUA_FILEHANDLE` userdata | `{FILE *f; lua_CFunction closef}`, size 16 |
| `lua_getextraspace(L)` | `(char *)L - LUA_EXTRASPACE` | 8 usable bytes *before* each `lua_State`, in every thread, copied from the main thread when a thread is created |
| `LUA_REGISTRYINDEX`, `lua_upvalueindex(i)` | Compiled-in constants | `-(INT_MAX/2 + 1000)` and that minus `i` |
| Type tags, status codes, `LUA_RIDX_*`, `LUA_OP*`, `LUA_GC*`, hook masks | Compiled-in constants | Stock values |
| `lua_CFunction`, `lua_KFunction`, `lua_Alloc`, `lua_Reader`, `lua_Writer`, `lua_Hook`, `lua_WarnFunction` | Foreign code pointers in both directions | Plain C calling convention |

`luaL_checkversion` has `LUA_VERSION_NUM` (505) and `LUAL_NUMSIZES` compiled in, so
modules that call it must pass. Everything else about the internals (`TValue`,
`Table`, `lua_State`'s fields past the extra space) is private and free to change
once no stock C shares it.

### 6.3 Errors and control flow across the boundary

A C function's call to `lua_error`, `luaL_error` or any raising `lua_*` function
never returns. `lua_yieldk`, `lua_callk` and `lua_pcallk` have the same shape.
That forces `luaD_throw` to be a real `longjmp` that crosses C frames the port
didn't compile, because the frames between the throw and the catch aren't Nucleus
frames. (`_setjmp`, `_longjmp`, `:returns-twice` and `:volatile` exist; see
`docs/structs-unions.md` and `examples/setjmp-guard.nuc`.)

The same jump crosses **Nucleus** frames, in the port and in Nucleus-written
libraries. Expect a `with` or `defer` cleanup in a jumped-over frame not to run,
and a value that `drop` should have released to leak; confirm this with a probe. Define a rule for the port and
document it for library authors, and record what the language should offer here.
This is one of the most important findings to get right. Test every combination:
Lua → C → Lua → error, and with Nucleus in place of each C, under `pcall`, inside
coroutines, with `yield` across `pcall` through continuations, and with to-be-closed
variables.

### 6.4 Variadics

`lua_pushfstring`, `luaL_error` and `lua_gc` are C variadics, and
`lua_pushvfstring` takes a `va_list`. Nucleus can call a C variadic but can't
define one (`design/deferred/overview.md`), so this is a `known-limitation`
finding with a real cost, and the reason `src/c/` exists. Put these four functions
in one small C file. The expected shape: the C entry point walks the format with
`va_arg`, and passes a plain array of decoded arguments to a Nucleus function that
does all the work. Internal variadics (`luaO_pushfstring`, `luaG_runerror`,
`luaK_semerror` and friends) have no ABI, so replace them with something idiomatic.

### 6.5 Libraries written in Nucleus

A library author with only this repository's binding must be able to write what
`mayi.c` does, and anything else the Lua manual's C API chapters allow, in Nucleus.

- **The binding** is a Nucleus library project under `capi/`, with its own
  `build.edn`, and with no dependency on the port's internals. It has two layers:
  - A low-level layer that is the C API one to one: the types, constants and
    every function, reached through `(import-use "lua.h")` if that works and by
    `declare` where it doesn't, plus a Nucleus equivalent of each function-like
    macro (`lua_pop`, `lua_newtable`, `lua_tostring`, `lua_upvalueindex`,
    `luaL_newlib`, `luaL_addchar`, `luaL_argcheck` and the rest). C header imports
    never admit a function-like macro, so these are hand-written. Check them against
    the header so they can't drift.
  - An idiomatic layer on top, in macros: defining a library in one form, instead of
    a function table kept in step by hand; argument checks that read like a
    signature; userdata tied to a Nucleus struct, with its metatable and `__gc`. Show
    what Nucleus adds over C here. If the idiomatic layer can't be made safe around
    `longjmp` (§6.3), say why and what would fix it.
- **The build.** One `build.edn` and one command must produce a loadable module:
  `mayi.so`, exporting `luaopen_mayi`, found by `require "mayi"` through an
  ordinary `?.so` cpath. The build tool's `:shared true` writes `lib<name>.so`, and
  Nucleus mangles namespaced names unless told otherwise (`set-ir-prefix ""`), so
  expect friction. Log it.
- **`libs/mayi/`** is a Nucleus port of `scratch/mayi.c` with the same behaviour.
  `FD_ZERO` and `FD_SET` are macros, so this little file already tests the interop.
- **`libs/nucdemo/`** is a substantial library, in idiomatic Nucleus, using the
  Nucleus standard library internally. It covers: a userdata type with a
  metatable, `__gc` and `__close`; closures with upvalues; a `luaL_Buffer`;
  registry references; callbacks into Lua; errors in both directions; and a
  yield across a call with a continuation function.
- **A Nucleus library must not need the port.** Built once, the same `.so` loads
  into the stock `lua` and the port. Two different Nucleus libraries must load
  into one process at once, into either host, and unload cleanly at `lua_close`.
- **Writing it down.** `docs/writing-libraries.md` is a short guide for someone who
  knows Nucleus and has never used Lua's C API: the skeleton, the build, the error
  rule from §6.3, and what's unsafe.

### 6.6 Known pressure points

These come from reading the docs. **None has been tried.** Start your probes here.

- **Shared runtime copies.** Every Nucleus object carries `weak_odr` copies of the
  prelude and its imports, plus an `@__nucleus_init` constructor. A host linked
  with `-Wl,-E` exports its copies, so a Nucleus `.so`'s symbols may bind to the
  host's, and the library's constructor may rerun initializers over the live host's
  globals when it's opened. Prefer exporting exactly the public Lua symbols
  (`-Wl,--dynamic-list`) over `-Wl,-E`, and record what happens with each. Check what
  `dlclose` does to that state.
- **Are library objects position-independent?** `clang -shared` needs that. Check it.
- **Variadic calls by `declare`.** Declared signatures are "open-tailed", while a
  header import has a real variadic flag. Check that
  `(luaL_error L "%f" 1.5)` passes the double correctly by both routes.
- **`luaL_Reg` tables as constant data.** A static array of `{name, function}` ended
  by nulls. Is a function address a constant initializer? Is the null representable?
- **Exported names and overloads.** A `defn` keeps its plain symbol only while it has
  one method in its namespace.
- **`long double` in a union**, for `luaL_Buffer`'s alignment.
- **Arithmetic.** Lua defines integer wraparound, shifts of 64 and beyond,
  `math.mininteger // -1`, floor division and modulo signs, float-to-integer range
  checks, NaN as a non-key, and `-0.0`. Find out what Nucleus defines and what it
  leaves to LLVM's `poison`.
- **C library surfaces that are macros or need care:** `errno`, `stdin`/`stderr`,
  `getc_unlocked`, `sig_atomic_t` and `signal`, `snprintf` with run-time format
  strings, `strftime`, `localeconv`, `setlocale`, `popen`, `CLOCKS_PER_SEC`.
- **No forced-inline or `likely` found in the docs.** `lvm.c` depends on both
  (`l_likely`, and macros that are always inlined). Find out what's possible.
- **C stack use.** `LUAI_MAXCCALLS` is 200, and `cstack.lua` runs right up to it.
  Nucleus frames must not be so large that the C stack overflows first.

## 7. Verification

Everything runs headless. Lua needs no display, so the reference is simply stock Lua
built from an unmodified copy. Commit recorded baselines; regenerate them only
deliberately.

### 7.1 The reference

`scripts/setup.sh` is idempotent and provisions the following. It runs on a fresh
machine and on the user's. It fetches and checks `../lua-5.5.1` and
`../lua-5.5.1-tests` (from the tarballs in §2) if they're missing, copies
`../lua-5.5.1` to `reference/build/` (gitignored), and there runs `make linux`,
which gives `reference/build/src/lua`, `luac` and `liblua.a`. It also builds the
test C libraries (`make -C libs LUA_DIR=<reference>/src`) and the stock-compiled
`mayi.so`. Run the suite from a copy too: it writes files in its working directory.

### 7.2 The official test suite

`all.lua` must pass, stdin must be a **pipe**, and the working directory must be the
suite. `files.lua` needs `io.stdin:seek` to fail, so `</dev/null` fails it even on
stock Lua. The tests below were all run on stock 5.5.1 and passed:

```
cd <suite> && : | <lua> all.lua               # full, about 10 s on stock
cd <suite> && <lua> -e '_U=true' all.lua      # portable subset, under 1 s
```

`scripts/check-suite.sh` runs the full form and reports the first failing file. It
is the main regression gate from milestone 2 on. `attrib.lua` loads `libs/*.so`, so
the suite also tests a few real C modules.

**The suite alone doesn't test the C API.** Without `T`, it prints `testC not
active: skipping API tests`, and the same for memory errors, userdata, coroutine
APIs and more. So §7.3 is mandatory, and milestone 10 exists.

### 7.3 The C API matrix

`scripts/check-capi.sh` is the gate for §6. It runs the same Lua driver script over
every cell, and the output must be identical across all of them:

| | stock `lua` | port `lua` |
|---|---|---|
| `scratch/mayi.c`, compiled by gcc | control | **must pass** |
| `libs/mayi` (Nucleus) | **must pass** | **must pass** |
| `tests/capi/capi.c`, compiled by gcc | control | **must pass** |
| `tests/capi/` in Nucleus, or `libs/nucdemo` | **must pass** | **must pass** |

The `.so` files are built once: no rebuild per host.

`mayi` behaviour, as measured on stock Lua. With stdin a pipe holding no data,
`mayi(0.01)` is `false`; with data ready, `mayi(0.2)` is `true`; the arguments
`"0.01"`, none, and `"x"` all return `false` on an idle pipe; and `require` returns
a table holding a function.

`tests/capi/capi.c` is a C module you write, whose driver exercises **every** public
function and macro at least once, compiled against the stock headers: the stack and
index conversions, tables, metatables, upvalues, userdata with user values,
`luaL_Buffer` in all its sizes (including overflow from the initial buffer into a
box), `luaL_ref`, `luaL_Stream`, `lua_getextraspace`, `lua_load` with a reader,
`lua_dump` with a writer, hooks, warnings, `lua_atpanic`, `lua_newstate` with a custom
allocator that counts and can fail on request (the memory-error path, and no bytes
left live after `lua_close`), a coroutine driven by `lua_resume`, continuations, and
every error route in §6.3. A control pass
against stock Lua proves the test before it judges the port. A coverage check compares
the names it calls against the 157 symbols.

The script also runs the symbol-table comparison, the header diff and the layout test
(§6.1, §6.2).

### 7.4 Bytecode identity

For a given source and platform, the compiler's output is deterministic: on stock
Lua, 68 dumps across the suite's files, stripped and not, were byte-identical from run
to run, and `luac -o` output equals `string.dump(loadfile(f))`. So the port's dumps
must be **byte-identical** to stock Lua's. `scripts/check-bytecode.sh` compares
`string.dump(loadfile(f), s)` for both values of `s` over every `.lua` in the suite,
and reports the first differing function. Binary chunks must also load across both
ways: stock dumps run on the port, and port dumps run on stock Lua.

This is the fastest way to find a lexer, parser or code generator bug. Don't compare
`luac -l` listings without filtering them: they print addresses.

### 7.5 Performance (measured, not gated)

`scripts/bench.sh` runs a small fixed set of Lua programs on the stock build and the
port, both at `-O2`: recursive calls, floating-point loops, table reads and writes,
string building, pattern matching, closures, metamethod dispatch, and GC churn. It
appends the ratios to `PROGRESS.md`.

From milestone 7 on, investigate anything above 1.5× stock until you can say why. A
slowdown the language imposes (a missed inline, a copied aggregate, a check you can't
remove, a poor indirect branch) is a finding. A slowdown you caused isn't.

### 7.6 Unit tests

Use the Nucleus test framework (`nucleus.test`, `docs/testing.md`) for things worth
testing directly: the arithmetic edge cases, number formatting and parsing, the
`macmap`-generated tables against the stock ones (`luaP_opmodes`, `luai_ctype_`, the
token names), and the binding's macro equivalents. Keep them in a test program, run by
`nucleus test`.

## 8. Recording findings — `ISSUES.md`

### What counts

Any place where the language, its standard library, its tooling, its diagnostics
or its docs made the port harder, longer, less clear or less safe than it should
be. Concretely:

- compiler bugs: crashes, miscompiles, wrong or misleading diagnostics, rejected
  valid code, accepted invalid code;
- missing features, where you had to fall back to a less idiomatic or more
  verbose form;
- design problems: features that exist but compose badly, surprise you, or push
  you toward C idioms;
- stdlib gaps (anything you had to write that belongs in `nucleus.*`);
- C interop friction, in **both** directions: importing headers, macros, varargs,
  unions and callbacks, and producing symbols, data layouts and shared objects that
  foreign code consumes;
- code generation quality, with the Nucleus and C-compiled assembly side by side;
- build-tool and workflow friction, slow compiles, and poor error locality in a
  large program;
- docs that are wrong, missing, or contradicted by the compiler.

**Notice friction actively.** After finishing each module, compare it with the C and
ask: where is the Nucleus version longer, harder to read, or less safe, and why?
Where did you reach for `ptr`, a cast or a manual loop because the idiomatic tool
didn't fit? What did the C preprocessor do more simply than a macro could? What did
the type system catch that C didn't? Where could it have, and didn't? Each answer is
a candidate finding.

### Format

`ISSUES.md` starts with a summary table ranked by **porter pain removed per unit
of language work**. Below the table, each issue looks like this:

```markdown
## ISSUE-007: <one-line claim, not a topic>

- **Severity:** blocker | major | minor | papercut
- **Kind:** bug | missing-feature | design | diagnostics | stdlib | interop | codegen | tooling | docs | known-limitation
- **Status:** open | worked-around | fixed in nucleus `<sha>`
- **Probe:** `probes/issue-007.nuc` — expected …, actual … (exact compiler output)
- **Port sites:** `src/vm/execute.nuc:212`, … (N sites in total)
- **Workaround:** what the port does instead, and what it costs
- **Suggestion:** what the language could do (optional, brief)
- **Prior art:** a Doom port's ISSUE-NNN (optional)

Context: one or two short paragraphs, with the idiomatic code you wanted to write
next to the code you had to write, and the C it came from when that helps.
```

Severity: **blocker** means no workaround was possible, so a feature was dropped
or a module couldn't be written. **Major** means the workaround costs
significant code, safety or clarity, or recurs widely. **Minor** is a local
annoyance. A **papercut** is cosmetic or a diagnostics wording issue.

Rules:
- **Every bug-kind issue needs a minimal standalone probe** in `probes/` that
  compiles (or fails to) with `$NUCLEUS_HOME/build/nucleusc` alone, with a header comment
  giving the issue id, the expected behaviour and a `; fixed-when:` pass condition.
  `scripts/check-probes.sh` reruns every probe and reports which issues still
  reproduce, so the language maintainers can rerun it after fixing the compiler.
- **Tag every workaround site** in the port with `; ISSUE-007` so that it can be
  removed once the issue is fixed. Tag each `src/c/` function too.
- **Log a finding when you hit it**, not at the end. A module isn't done until
  its findings are in `ISSUES.md`.
- Merge duplicates, and update a finding's site count and severity as evidence
  accumulates.
- Keep a short **"What worked well"** section at the end, listing features that
  clearly beat the C. That is signal too.

### Fixing the compiler

You may fix **bugs**: crashes, miscompiles, rejected valid code, accepted invalid
code, wrong diagnostics, and docs that contradict the compiler. Missing features,
design problems and stdlib gaps are recorded only, because they are the
language designer's decisions. A bug whose fix needs a design decision counts as
a design problem.

- **When to fix.** Fix a bug when it blocks the port, or when its workaround is
  costly or recurs widely. Otherwise record it, work around it, and move on.
  Don't let compiler work crowd out the port. The port is how findings are made.
- **Where.** Work on the branch `lua-bugfixes` in your Nucleus tree, created from
  `iron-doom-bugfixes` (`1e0fbb3`), which holds the fixes the Iron Doom port made. Never
  commit to `main` there. Before your first change, read that repo's `CLAUDE.md`,
  `context/conventions.md` and `context/build.md`, and follow its rules (tests,
  bootstrap, docs, `design/progress.md`, context files, comment budget). Its
  subagent guidance and `context/local.md` don't apply here.
- **How.** The order is probe first, then the fix, then the gates:
  1. Write the probe (§8 rules) and record the issue.
  2. Make the fix.
  3. With `scripts/env.sh` sourced, run `make -C "$NUCLEUS_HOME"`, then
     `make -C "$NUCLEUS_HOME" -k test bootstrap`. The suite takes a long time (about
     25 minutes on the Doom containers), so run it in the background. Compare against
     the baseline recorded in `CLAUDE.md`, not against zero.
  4. Add a regression test in the Nucleus suite.
  5. Make one commit per fix on `lua-bugfixes`, naming the ISSUE id. If you can't push
     there, `git format-patch` it into this repo's `nucleus-patches/`, as the Iron Doom
     port did. If the fix changes the compiler's own codegen, follow `context/build.md`
     for moving the bootstrap.
- **Afterwards.** Set the issue's status to `fixed in nucleus <sha>` (the finding
  stays in `ISSUES.md`), confirm that `check-probes.sh` reports the probe as
  fixed, and remove the port's `; ISSUE-NNN` workarounds.

## 9. Design guidance — translate these

These are suggestions, not mandates. If one turns out worse in Nucleus than in C,
that is a finding.

**The migration: keep it running.** Don't write 30,000 lines and then debug them all
at once. The stock C modules have clean internal interfaces, so port one `.c` file at
a time and keep the remaining stock objects linked, with the suite green at every
step. `lua.c`, `lauxlib.c` and the standard libraries call only the public API, so they
come first, against the stock core. (They link to nothing else, though they include
`llimits.h` for utility macros.) Then replace the core a module at a time. Stock
sources compile unmodified from `../lua-5.5.1/src`. How the hybrid links is yours to
design: if `build.edn` makes it awkward, that's a finding. Write the decision and its
reasons at the top of `PROGRESS.md` in milestone 0. If you decide against this and
port the core in one piece, say why there.

While any stock C shares a structure, **that structure's Nucleus layout must match the
C exactly**, and functions the C calls keep their C names (`luaH_get`, `luaX_next`).
Check layouts with the `offsetof` test. Everything else is free from the start: write
function bodies idiomatically, and don't wait for the idiom pass to use macros, tables
and narrowed references. Milestone 9 then removes the layout and naming constraints
that only the migration imposed.

Organize the code by subsystem under Nucleus namespaces (for example `lua.obj`,
`lua.compile`, `lua.vm`, `lua.gc`, `lua.api`, `lua.lib.*`), rather than one file per
`.c`. Use the build tool (`build.edn`), not hand-written compiler command lines. Use
Nucleus naming (kebab-case functions, CamelCase types) for everything except the
exported C names. Follow the Nucleus repo's comment style: comments say *why*, in one
or two lines. Lua's own comments are good; carry over the ones that explain a subtle
invariant.

| Lua (C) | Nucleus direction |
|---|---|
| About 670 function-like macros (`setobj`, `ttisinteger`, `gco2ts`, …) | `defn` where inlining is reliable, `defmacro` where it's about places or control flow. Record where neither was as good as the preprocessor |
| Opcodes kept in step across `lopcodes.h`, `lopnames.h`, `ljumptab.h`, `luaP_opmodes`; tokens in `llex.h` and `luaX_tokens`; `TMS` in `ltm.h` and `luaT_init` | One `macmap` row set generating the enum, names, modes and jump table |
| `lctype.c`'s table, `luaO_ceillog2`'s `log_2` | Compile-time evaluation, tested equal to the original (§7.6) |
| `TValue`: a `Value` union plus a tag byte with variant and collectable bits | A struct over an untagged `(union …)`, since the tag's bit layout matters. Say what `defunion` would need to carry this |
| `GCObject`, `CommonHeader`, `gco2*`, `cast` | Typed views over the header, checked by tag in assertion builds. Record every unchecked cast and what could have made it checked |
| `Node`'s overlay union, `TString` and `Udata` trailing data, closures with `upvals[1]` | Flexible array members, `:packed` if needed, and typed accessors |
| `l_noret`, `luaD_throw`, `LUAI_TRY` | `:noreturn`, `_setjmp`/`_longjmp`. `!T` can't replace a throw that must cross foreign frames. Say where `!T` does work: self-contained code such as number parsing or `luac`'s options |
| `luaV_execute`, `vmdispatch`, `vmcase`, `vmbreak`, `op_arith` families | `label-addr`, `goto-ptr`, and `macrolet` for the operator families |
| `Protect`, `savestate`, `updatebase`, `trap` | Macros that keep the "stack may have moved" rule visible. Could the type system help? |
| `lua_assert`, `api_check`, `LUAI_APICHECK` | One compile-time switch. Run the suite with it on at each milestone |
| `lua_Alloc`, `luaM_*`, `luaM_growvector`, `Dyndata` | All collector-visible memory goes through the state's `lua_Alloc`. Try the stdlib allocator protocol and collections over it. Allocation failure raises a Lua error by `longjmp`, and GC debt must stay exact, so record whether they survive that |
| `luaL_Buffer`-based string building in libraries | Keep it where Lua errors can occur. `String`/`StrView`/`fmt` only where nothing can jump over them |
| `FILE *` in `liolib.c`, `luaL_Stream` | `FILE *` stays: it's public (§6.2). `nucleus.file` can't replace it |
| `str_format`, `lua_number2strx`, `tostringbuff` | The exact `%.14g` output is observable. Use `snprintf` and record the friction |
| `lstrlib.c` pattern matching, `str_pack` | Idiomatic: `defunion` for parsed `KOption`, `StrView` over subjects where lifetimes allow |
| `lua.c`'s option parsing and `laction` signal handler | A `Const` flag table; `signal` through C interop |
| `expdesc`, `BinOpr`/`UnOpr` tables, the parser's `kind`-dependent union | `defunion` + `match` for `expdesc` if the bytecode stays identical. Record any lost exhaustiveness check |

## 10. Milestones

Do these in order. Each one ends with green gates, any new findings logged, an
update to `PROGRESS.md`, and a commit.

0. **Setup.** `git init`, `.gitignore`, `scripts/env.sh`, `scripts/setup.sh` and
   `build.edn`. Get a working compiler (§3 rule 9). Record its Nucleus test baseline
   in `CLAUDE.md`, and write `CLAUDE.md` so a fresh session can resume from it. Do
   the required reading (§4), and make the migration decision (§9). Write `LICENSE`,
   the `ISSUES.md` skeleton, `probes/` and `scripts/check-probes.sh`. Build the
   reference (§7.1) and confirm §7.2's and §7.3's stock results here. Then do a
   **spike**: the smallest Nucleus `luaopen_` module that loads into stock `lua` and
   returns one function that raises an error caught by `pcall`. It answers most of
   §6.6 early, and everything depends on it. *Gate:* the spike works, or its blocker
   is an ISSUE with a probe.
1. **The binding and the first library.** `capi/`, both layers, the layout test,
   `libs/mayi`, `tests/capi/capi.c`, and the stock column of the matrix.
   *Gate:* `libs/mayi` loads into stock `lua`, and the stock column of §7.3 passes.
2. **Port-owned host and libraries.** On the stock core, port `lua.c`, `lauxlib.c`
   (with `src/c/`'s variadic `luaL_error`), then each standard library. Each is
   ordinary Nucleus Lua-library code, so the binding gets its first real use: fix it
   here. *Gate:* `check-suite.sh` passes, and §7.3's port column passes with a Nucleus
   `main` over the stock core.
3. **Object model.** `lctype`, `lzio`, `lmem`, `lobject`, `lstring`, `lfunc`, `ltm`,
   `ltable`. *Gate:* the suite after each module.
4. **Compiler.** `lopcodes`, `llex`, `lcode`, `lparser`, `ldump`, `lundump`, then
   `luac.c`. *Gate:* the suite and `check-bytecode.sh`, after each module.
5. **Execution state.** `ldebug`, `lstate`, `ldo` (throw, calls, coroutines and
   continuations), `lapi` (the rest of the variadics). *Gate:* suite, bytecode, matrix.
6. **The collector.** `lgc`, incremental and generational. Also run the suite from a
   driver that uses `collectgarbage("param", …)` to collect as often as it can, in
   both modes, since missing write barriers hide from ordinary runs. *Gate:* suite,
   bytecode, matrix, and those stressed runs.
7. **The VM.** `lvm`, computed `goto` included. Stock C is now gone from the link,
   except `src/c/`. *Gate:* all gates, with `nm` showing no stock object. Benchmark
   (§7.5). Post a **user test request** (below).
8. **Nucleus libraries complete.** `libs/nucdemo`, the Nucleus side of `tests/capi/`,
   and `docs/writing-libraries.md`. *Gate:* the full matrix, including two Nucleus
   libraries loaded at once into each host, and the unload path. Post a user test request.
9. **Idiom pass.** Now that no C shares the layouts, rename internals to Nucleus style,
   revisit the modules written early with the experience gained since, and redo anything
   the migration held back. Rerun the benchmarks, and investigate what §7.5 requires.
   *Gate:* all gates.
10. **The `T` harness (optional, but strongly wanted).** Port as much of `ltests.c`
    (2,250 lines) as gives `T.testC`, `T.checkmemory` and the allocator checks, so that
    `api.lua`, `memerr.lua` and the skipped sections run. `ltests.h` changes constants
    such as `LUAL_BUFFERSIZE`, `LUA_EXTRASPACE`, `LUAI_MAXSTACK` and `LUAI_MAXCCALLS`, so
    this needs a compile-time configuration, which is a test of its own. This is the
    deepest API coverage Lua has. Stop early if it stops paying.
11. **Final report.** Finalize the `ISSUES.md` ranking, and add a per-subsystem table
    comparing C line counts with Nucleus line counts, and a code generation section.
    Write a short executive summary at the top: the five changes that would help most,
    and why.

**User test requests.** The user tries the port on their own machine. A request is a
section in `PROGRESS.md` that gives:
- the exact commands to build it there: check out the branch, build Nucleus at the
  named commit, point `NUCLEUS_HOME` at it, and run the build;
- what to try, including building `scratch/mayi.c` and `libs/mayi` and loading each;
- known problems.

Mention the request in your reply too. **Don't block on it.** Continue with the next
milestone, and work any feedback that comes back in as soon as it arrives.

## 11. Working practices

- **Progress tracking.** Keep `PROGRESS.md` current: the milestone status, which C
  files are still stock, what's in progress, the next steps and any open questions.
  Assume your context will be compacted and that another session, possibly on a fresh
  machine, may pick the work up from `PROGRESS.md` and `CLAUDE.md` alone.
- **Small increments.** Work in steps that build and commit cleanly, so that a session
  limit or a compaction never strands work. Before each long step (a compiler test run,
  a full gate run), make sure `PROGRESS.md` says what is in flight.
- **Probing.** When the compiler surprises you, stop and write the probe *before*
  working around the problem; this keeps the workaround from hiding it. Use
  `nucleusc --run` or the REPL for quick experiments (see the Nucleus
  `docs/compiler.md` and `context/repl.md`). `nucleus run` builds a binary instead of using
  the JIT when a project has `:c-sources`, and `run-repl` refuses it, because a C object
  can't join a JIT session.
- **Debugging a port bug.** Stock Lua is your oracle. Narrow to one Lua script that
  differs, then compare the bytecode (§7.4) before suspecting the VM. A crash that
  appears only with Nucleus code in the link might be a layout mismatch, so run the
  `offsetof` test first.
- **Self-improving context.** When you learn something non-obvious about the
  environment, the toolchain or a workflow, add it to `CLAUDE.md`. Language
  findings go to `ISSUES.md`, not `CLAUDE.md`.

## 12. Definition of done

- Every in-scope milestone is complete with its gates green, and the work is committed.
- `lua` and `luac` contain no C but `src/c/`, and each function there names its ISSUE.
- `scripts/check-suite.sh`, `scripts/check-capi.sh`, `scripts/check-bytecode.sh`,
  `scripts/check-probes.sh` and the unit tests all run on a fresh machine after
  `scripts/setup.sh`, following only the instructions in `CLAUDE.md`, and on the user's
  machine with `NUCLEUS_HOME` set.
- `scratch/mayi.c`, compiled by gcc against the stock headers and not otherwise changed,
  and `libs/mayi`, built with Nucleus, each load unrebuilt into both the stock `lua` and
  the port, and behave identically.
- `ISSUES.md` is ranked and evidenced: every bug has a probe, every workaround is
  tagged in the code, and the executive summary, line-count table and code generation
  section are written.
- Every compiler fix is committed on `lua-bugfixes` (or in `nucleus-patches/`) with a
  passing Nucleus test suite and bootstrap, and the `ISSUES.md` entry for each one names
  its commit.
