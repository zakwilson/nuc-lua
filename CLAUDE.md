# nuc-lua

Lua 5.5.1 ported to Nucleus, as a stress test of the language. `PROMPT.md` is the
brief and the source of truth for scope, rules and milestones. `PROGRESS.md` says
where the work stands; `ISSUES.md` holds the language findings.

## Resuming

1. `source scripts/env.sh` finds a compiler that runs: `$NUCLEUS_HOME`, else
   `../nucleus`, `../nucleus-work`, then `.nucleus-work` (a clone inside this repo,
   gitignored, because `/home/zak/code` itself isn't writable here and
   `../nucleus/build/nucleusc` wants an LLVM this machine lacks).
2. `scripts/setup.sh` builds the stock reference into `reference/build/` and copies
   the official suite to `build/suite/`.
3. Read `PROGRESS.md`, then the milestone in `PROMPT.md` §10 it names.

## The compiler clone

`.nucleus-work` is a clone of `../nucleus` on branch `lua-bugfixes`. Build it with
`make -j16` there. Compiler fixes are committed there, then fast-forwarded into
`../nucleus` (`git -C ../nucleus fetch ../nuc-lua/.nucleus-work lua-bugfixes:lua-bugfixes`)
and `git format-patch`ed into `nucleus-patches/`. There is no push access.

Never rebuild `../nucleus/build`. Never discard work with git in any repo.

**Gate for a compiler change:** run the suite and bootstrap from a snapshot, so
editing can go on: rsync `.nucleus-work` (excluding `/build`, not `build`, which
would also drop `lib/nucleus/build/`) to a scratch tree, `make`, copy
`build/nucleusc` over `bin/nucleusc` (the boot IR predates the branch, so the
fixed point needs a second round), `make`, then `make -k test` and `make bootstrap`.

**Baseline** (lua-bugfixes at `bc1b05d`, before any change of this port's):
`nuctests: 1725 passed, 0 failed, 0 skipped`, bootstrap fixed point holds.
Latest (`b8e711e`): 1744 passed, bootstrap holds. After `a64ac73` it held only from
the third round (a fix the compiler's own sources depend on changes the order a
compiler built without it emits).

## Gotchas

- `pkill -f` / `pgrep -f` with a pattern that appears in your own command line
  kills your own shell. Use `pgrep -x`.
- The official suite needs stdin to be a pipe: `cd build/suite && : | lua all.lua`.
- An idle pipe is `sleep 1 | lua …`; `printf '' |` is at EOF, which `select` calls readable.
- A `:shared true` library builds `build/lib/lib<name>.so`; `require` wants `<name>.so`.
- After editing `capi/` (the binding), rebuild `lua` itself too: the port imports the
  binding, and gates run on a stale `build/lua` pass without noticing.
- A public `defn` in a `.so` is preempted by any same-named symbol in the process
  (ISSUE-005), so Lua C functions in a library are `defn-`.
