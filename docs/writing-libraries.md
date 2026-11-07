# Writing a Lua library in Nucleus

For someone who knows Nucleus and has not used Lua's C API. The binding is
`capi/` (namespace-free, `(import-use luacapi)`); `libs/mayi` is the smallest
example and `libs/nucdemo` the full one. A library built this way loads, unchanged,
into stock `lua` and into this port.

## The model in brief

Lua calls a C function as `int f(lua_State *L)`. The arguments are on a stack, at
indices 1 to `lua_gettop(L)`; negative indices count from the top. A function pushes
its results and returns how many. `require "name"` finds `name.so` on
`package.cpath`, calls its `luaopen_name`, and keeps what that returns, usually a
table of functions.

Every `lua_*` and `luaL_*` function is in the binding under its C name; the C
macros (`lua_pop`, `lua_tostring`, `luaL_checkstring`, `lua_upvalueindex`, …) are
Nucleus macros of the same name and arguments. The manual's chapters 4 and 5 apply
word for word.

## The skeleton

```lisp
(ns mylib)
(set-ir-prefix "")      ; luaopen_mylib keeps its C name
(import-use luacapi)

(defn-lua add (L (a integer) (b integer 1))   ; b is optional, default 1
  (lua_pushinteger L (+ a b))
  (return 1))

(deflualib luaopen_mylib
  (("add" add)))
```

`defn-lua` turns the parameter list into the argument checks C writes by hand:
`integer`, `number`, `string`, `boolean`, `any`, `table`, `function`, or
`(udata T "tname")`, each optionally with a default. The function it defines is
private (`defn-`): Lua reaches it through a table, and a public name in a shared
object can be preempted by any same-named symbol in the process (ISSUE-005).

`deflualib` writes `luaopen_…`: the function table, plus a metatable per userdata
type, registered under its name, whose `__index` is itself:

```lisp
(deflualib luaopen_mylib
  (("new" counter-new))
  (("mylib.Counter" ("get" counter-get) ("__gc" counter-gc))))
```

`(lua-new-udata L T "mylib.Counter")` makes a zeroed userdata holding a `T` with that
metatable; `(c (udata T "mylib.Counter"))` in a `defn-lua` checks and binds one.

## The build

```clojure
{:kind :library
 :name "mylib"
 :version "1.0"
 :shared true
 :link-args ["-Wl,--version-script=exports.map"]
 :deps {luacapi {:path "../../capi"}}}
```

with `exports.map`:

```
{ global: luaopen_mylib; local: *; };
```

`nucleus build` writes `build/lib/libmylib.so`; `require` wants `mylib.so`, so copy or
link it under that name (ISSUE-007; `scripts/build-libs.sh` does this for `libs/*`).

The version script matters once the library imports the standard library: every
`Vector` or `HashMap` method it uses is otherwise exported, and a library loaded with
`package.loadlib(path, "*")` would lend its copies to the next one (ISSUE-049).

## The error rule

A Lua error is a `longjmp`. `lua_error`, `luaL_error`, every `luaL_check*`, and any
call that can allocate (pushing a string, creating a table) can leave your function
without returning, straight to the `pcall` that is waiting. Nucleus's cleanups are
lexical, so the jump runs none of the frames' `defer`s and `with` releases, and frees
no `Drop` value (ISSUE-047). Hence:

1. **A function Lua calls holds nothing that needs a cleanup across a call that can
   raise or yield.** No `defer`, no `with`-owned binding, no `Drop` value live there.
2. **Own things in helpers that do not call Lua**, and have them return a `Result`.
   Raise after they have returned, when their cleanups have run:

   ```lisp
   (defn- parse-int (s:CStr len:usize):!i64
     (with (buf:(ptr i8) (as (ptr i8) (malloc (+ len 1))))
       …                                    ; any (return (err …)) frees buf
       (return (ok v))))

   (defn-lua parse (L (s any))
     (let (len:&usize (alloca usize)
           p:CStr (luaL_checklstring L s len))
       (match (parse-int p (deref len))
         ((ok v) (lua_pushinteger L v))
         ((err e) (luaL_error L "%s" (err-message e))))
       (return 1)))
   ```
3. **What must stay alive while Lua runs belongs to Lua.** Put it in a userdata
   whose `__gc` releases it: if an error interrupts you, the collector cleans up.
   `nucdemo`'s `words` keeps its `HashMap` that way while it pushes the results, then
   releases it early.
4. **Errors from Lua come back as values** through `lua_pcall`, which returns a status
   in your frame: nothing is skipped. Convert it to a `Result` if that reads better.
5. **A local changed after `_setjmp` and read after the jump must be `:volatile`.**
   Only code that calls `_setjmp` itself, such as a panic handler, needs this.

## Yields and continuations

A Lua function called with `lua_call` from your function may `coroutine.yield`,
but only if you give a continuation: `lua_callk`, `lua_pcallk` or `lua_yieldk` with a
`lua_KFunction` `(L:&lua_State status:i32 ctx:lua_KContext):i32`. When the coroutine
resumes, your frame is gone and Lua calls the continuation instead, so everything the
rest of the work needs travels in `ctx` (an integer) or on the Lua stack. The rule
above holds doubly: a yield is a `longjmp` too. `nucdemo`'s `each` keeps its loop
index in `ctx`; its `try` is `pcall` written with `lua_pcallk`.

## What is unsafe

- Holding a cleanup across a raising call (above). The compiler does not warn.
- A `CStr` from `lua_tostring` points into a Lua string: valid only while that string
  is reachable, typically while it stays on the stack.
- `=` on two `CStr`s compares their contents; to compare a pointer with `null`, cast it
  to `ptr` first (ISSUE-042).
- A public `defn` in a library (ISSUE-005); a function address in a constant
  `luaL_Reg` array is refused, so `deflualib` builds its tables at run time (ISSUE-004).
- The stack has `LUA_MINSTACK` (20) free slots on entry; push more only after
  `luaL_checkstack`.

## Testing

`scripts/check-capi.sh` loads each library, built once, into stock `lua` and the port
and compares what they print. `tests/capi/nuc` is the whole C API, called from
Nucleus; `tests/capi/nucdemo.lua` drives `nucdemo` with `mayi` loaded beside it, and
both `capi` modules check that the two libraries are unmapped after `lua_close`.
