/*
** The C API matrix's test module (PROMPT.md §7.3). It calls every public
** function and macro of lua.h, lauxlib.h and lualib.h, and prints a transcript
** that holds no addresses, so stock lua and the port must print the same.
** Built once by gcc against the stock headers; it is never rebuilt per host.
*/
#include <errno.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#define say(...) (printf(__VA_ARGS__), fflush(stdout))

/* A value as text, with no address in it. */
static const char *show(lua_State *L, int i) {
  static char ring[8][128];
  static int next;
  char *buf = ring[next++ % 8];
  i = lua_absindex(L, i);
  switch (lua_type(L, i)) {
    case LUA_TNONE: return "none";
    case LUA_TNIL: return "nil";
    case LUA_TBOOLEAN: return lua_toboolean(L, i) ? "true" : "false";
    case LUA_TNUMBER:
      if (lua_isinteger(L, i))
        snprintf(buf, 128, "%lld", (long long)lua_tointeger(L, i));
      else
        snprintf(buf, 128, "%.14g", (double)lua_tonumber(L, i));
      return buf;
    case LUA_TSTRING:
      snprintf(buf, 128, "'%s'", lua_tostring(L, i));
      return buf;
    default: return luaL_typename(L, i);
  }
}

static void stack(lua_State *L, const char *tag) {
  int i, n = lua_gettop(L);
  printf("%s [%d]", tag, n);
  for (i = 1; i <= n; i++) printf(" %s", show(L, i));
  say("\n");
}

/* Runs Lua source, printing an error instead of raising it. */
static void run(lua_State *L, const char *src) {
  if (luaL_dostring(L, src)) {
    say("error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
}

/* ---- the stack and conversions ---- */

static int f_noop(lua_State *L) { (void)L; return 0; }

static void t_stack(lua_State *L) {
  int isnum = -1;
  size_t len;
  lua_settop(L, 0);
  lua_pushnil(L);
  lua_pushboolean(L, 7);
  lua_pushinteger(L, 42);
  lua_pushnumber(L, 2.5);
  lua_pushstring(L, "10");
  lua_pushlstring(L, "a\0b", 3);
  lua_pushliteral(L, "lit");
  lua_pushcfunction(L, f_noop);
  lua_pushlightuserdata(L, &isnum);
  lua_pushglobaltable(L);
  stack(L, "pushed");
  say("absindex(-1)=%d top=%d checkstack=%d\n", lua_absindex(L, -1),
      lua_gettop(L), lua_checkstack(L, 100));
  say("types:");
  for (int i = 1; i <= 10; i++) printf(" %s", lua_typename(L, lua_type(L, i)));
  say(" %s\n", lua_typename(L, lua_type(L, 99)));
  say("isnumber %d %d %d isstring %d %d iscfunction %d isinteger %d %d "
      "isuserdata %d %d\n", lua_isnumber(L, 3), lua_isnumber(L, 5),
      lua_isnumber(L, 6), lua_isstring(L, 3), lua_isstring(L, 1),
      lua_iscfunction(L, 8), lua_isinteger(L, 3), lua_isinteger(L, 4),
      lua_isuserdata(L, 9), lua_isuserdata(L, 3));
  say("is* %d %d %d %d %d %d %d %d\n", lua_isfunction(L, 8),
      lua_istable(L, 10), lua_islightuserdata(L, 9), lua_isnil(L, 1),
      lua_isboolean(L, 2), lua_isthread(L, 2), lua_isnone(L, 11),
      lua_isnoneornil(L, 1));
  {
    lua_Number n = lua_tonumberx(L, 5, &isnum);
    say("tonumberx %.14g/%d ", n, isnum);
    n = lua_tonumberx(L, 7, &isnum);
    say("%.14g/%d ", n, isnum);
  }
  {
    lua_Integer i = lua_tointegerx(L, 4, &isnum);
    say("tointegerx %lld/%d ", (long long)i, isnum);
    i = lua_tointegerx(L, 5, &isnum);
    say("%lld/%d\n", (long long)i, isnum);
  }
  say("tonumber %.14g tointeger %lld toboolean %d %d\n", lua_tonumber(L, 4),
      (long long)lua_tointeger(L, 3), lua_toboolean(L, 1),
      lua_toboolean(L, 2));
  lua_tolstring(L, 6, &len);
  say("tolstring len %zu rawlen %llu tocfunction %d touserdata %d "
      "tothread %d topointer %d\n", len, (unsigned long long)lua_rawlen(L, 6),
      lua_tocfunction(L, 8) == f_noop, lua_touserdata(L, 9) == &isnum,
      lua_tothread(L, 2) == NULL, lua_topointer(L, 10) != NULL);
  lua_tostring(L, 3); /* converts the integer in place, as documented */
  say("after tostring: %s\n", show(L, 3));
  lua_settop(L, 4);
  lua_rotate(L, 1, 1);
  stack(L, "rotate");
  lua_insert(L, 2);
  stack(L, "insert");
  lua_remove(L, 1);
  stack(L, "remove");
  lua_pushinteger(L, 9);
  lua_replace(L, 1);
  stack(L, "replace");
  lua_copy(L, 1, 3);
  lua_pushvalue(L, 2);
  stack(L, "copy+pushvalue");
  lua_pop(L, 2);
  stack(L, "pop");
  {
    /* in turn: as arguments of one call, their pushes come in any order */
    size_t s1 = lua_stringtonumber(L, "0x10");
    size_t s2 = lua_stringtonumber(L, " 1e2 ");
    size_t s3 = lua_stringtonumber(L, "zz");
    say("stringtonumber %zu %zu %zu\n", s1, s2, s3);
  }
  stack(L, "stringtonumber");
  {
    char nb[LUA_N2SBUFFSZ];
    lua_pushnumber(L, 0.1);
    lua_pushinteger(L, -7);
    unsigned n1 = lua_numbertocstring(L, -2, nb);
    say("numbertocstring %u '%s' ", n1, nb);
    n1 = lua_numbertocstring(L, -1, nb);
    say("%u '%s'\n", n1, nb);
  }
  lua_settop(L, 0);
}

/* ---- arithmetic, comparison, concatenation, length ---- */

static void t_ops(lua_State *L) {
  static const struct { int op; const char *name; int nargs; } ops[] = {
    {LUA_OPADD, "add", 2}, {LUA_OPSUB, "sub", 2}, {LUA_OPMUL, "mul", 2},
    {LUA_OPMOD, "mod", 2}, {LUA_OPPOW, "pow", 2}, {LUA_OPDIV, "div", 2},
    {LUA_OPIDIV, "idiv", 2}, {LUA_OPBAND, "band", 2}, {LUA_OPBOR, "bor", 2},
    {LUA_OPBXOR, "bxor", 2}, {LUA_OPSHL, "shl", 2}, {LUA_OPSHR, "shr", 2},
    {LUA_OPUNM, "unm", 1}, {LUA_OPBNOT, "bnot", 1}};
  say("arith:");
  for (size_t i = 0; i < sizeof ops / sizeof ops[0]; i++) {
    lua_pushinteger(L, -7);
    if (ops[i].nargs == 2) lua_pushinteger(L, 3);
    lua_arith(L, ops[i].op);
    printf(" %s=%s", ops[i].name, show(L, -1));
    lua_pop(L, 1);
  }
  say("\n");
  lua_pushinteger(L, 1);
  lua_pushnumber(L, 1.0);
  lua_pushstring(L, "1");
  say("compare eq %d lt %d le %d rawequal %d %d invalid %d\n",
      lua_compare(L, 1, 2, LUA_OPEQ), lua_compare(L, 1, 2, LUA_OPLT),
      lua_compare(L, 1, 2, LUA_OPLE), lua_rawequal(L, 1, 2),
      lua_rawequal(L, 1, 3), lua_compare(L, 1, 9, LUA_OPEQ));
  lua_concat(L, 3);
  say("concat3 %s ", show(L, -1));
  lua_concat(L, 0);
  say("concat0 %s ", show(L, -1));
  lua_pushinteger(L, 5);
  lua_concat(L, 1);
  say("concat1 %s\n", show(L, -1));
  lua_settop(L, 0);
  run(L, "capi_t = setmetatable({1,2,3}, {__len = function() return 99 end})");
  lua_getglobal(L, "capi_t");
  lua_len(L, 1);
  say("len %s luaL_len %lld rawlen %llu\n", show(L, -1),
      (long long)luaL_len(L, 1), (unsigned long long)lua_rawlen(L, 1));
  lua_settop(L, 0);
}

/* ---- tables and metatables ---- */

static int f_index(lua_State *L) {
  lua_pushfstring(L, "idx:%s", lua_tostring(L, 2));
  return 1;
}

static void t_tables(lua_State *L) {
  static char key;
  int t;
  lua_createtable(L, 2, 2);
  t = lua_gettop(L);
  lua_pushstring(L, "v1");
  lua_setfield(L, t, "a");
  lua_pushstring(L, "k");
  lua_pushstring(L, "v2");
  lua_settable(L, t);
  lua_pushinteger(L, 10);
  lua_seti(L, t, 1);
  lua_pushinteger(L, 20);
  lua_rawseti(L, t, 2);
  lua_pushstring(L, "rk");
  lua_pushinteger(L, 30);
  lua_rawset(L, t);
  lua_pushstring(L, "pv");
  lua_rawsetp(L, t, &key);
  int ty = lua_getfield(L, t, "a");
  say("getfield %d %s ", ty, show(L, -1));
  lua_pushstring(L, "k");
  ty = lua_gettable(L, t);
  say("gettable %d %s ", ty, show(L, -1));
  ty = lua_geti(L, t, 1);
  say("geti %d %s ", ty, show(L, -1));
  ty = lua_rawgeti(L, t, 2);
  say("rawgeti %d %s ", ty, show(L, -1));
  lua_pushstring(L, "rk");
  ty = lua_rawget(L, t);
  say("rawget %d %s ", ty, show(L, -1));
  ty = lua_rawgetp(L, t, &key);
  say("rawgetp %d %s\n", ty, show(L, -1));
  lua_settop(L, t);
  {
    int count = 0;
    lua_pushnil(L);
    while (lua_next(L, t)) { count++; lua_pop(L, 1); }
    say("next visited %d\n", count);
  }
  lua_newtable(L);
  lua_pushcfunction(L, f_index);
  lua_setfield(L, -2, "__index");
  int ty0 = lua_getmetatable(L, t);
  say("getmetatable before %d ", ty0);
  lua_setmetatable(L, t);
  say("after %d ", lua_getmetatable(L, t));
  lua_pop(L, 1);
  lua_getfield(L, t, "zz");
  say("via __index %s ", show(L, -1));
  lua_pop(L, 1);
  lua_pushstring(L, "zz");
  lua_rawget(L, t);
  say("rawget %s\n", show(L, -1));
  lua_pop(L, 1);
  lua_pushvalue(L, t);
  lua_setglobal(L, "capi_tab");
  ty = lua_getglobal(L, "capi_tab");
  say("getglobal %d ", ty);
  say("same %d\n", lua_rawequal(L, -1, t));
  lua_settop(L, 0);
  ty = luaL_getsubtable(L, LUA_REGISTRYINDEX, "capi_sub");
  say("getsubtable %d %d\n", ty, luaL_getsubtable(L, LUA_REGISTRYINDEX, "capi_sub"));
  lua_settop(L, 0);
}

/* ---- C closures, upvalues, luaL_setfuncs, luaL_newlib, requiref ---- */

static int f_counter(lua_State *L) {
  lua_Integer n = lua_tointeger(L, lua_upvalueindex(1)) + 1;
  lua_pushinteger(L, n);
  lua_copy(L, -1, lua_upvalueindex(1));
  lua_pushvalue(L, lua_upvalueindex(2));
  return 2;
}

static int f_shared(lua_State *L) {
  lua_pushvalue(L, lua_upvalueindex(1));
  return 1;
}

static const luaL_Reg shared_funcs[] = {
  {"one", f_shared}, {"two", f_shared}, {"placeholder", NULL}, {NULL, NULL}};

static int f_double(lua_State *L) {
  lua_pushinteger(L, 2 * luaL_checkinteger(L, 1));
  return 1;
}

static const luaL_Reg minilib[] = {{"double", f_double}, {NULL, NULL}};

static int open_minilib(lua_State *L) {
  luaL_newlib(L, minilib);
  return 1;
}

static void t_closures(lua_State *L) {
  lua_pushinteger(L, 0);
  lua_pushstring(L, "tag");
  lua_pushcclosure(L, f_counter, 2);
  lua_setglobal(L, "capi_counter");
  run(L, "print('counter', capi_counter()) print('counter', capi_counter())");
  lua_getglobal(L, "capi_counter");
  {
    const char *un = lua_getupvalue(L, -1, 1);
    say("getupvalue '%s' %s ", un, show(L, -1));
  }
  lua_pop(L, 1);
  lua_pushinteger(L, 100);
  say("setupvalue '%s' ", lua_setupvalue(L, -2, 1));
  say("getupvalue(3) %s\n", lua_getupvalue(L, -1, 3) ? "yes" : "NULL");
  run(L, "print('counter', capi_counter())");
  lua_newtable(L);
  lua_pushstring(L, "up");
  luaL_setfuncs(L, shared_funcs, 1);
  lua_getfield(L, -1, "one");
  lua_call(L, 0, 1);
  say("setfuncs one %s ", show(L, -1));
  lua_pop(L, 1);
  lua_getfield(L, -1, "placeholder");
  say("placeholder %s\n", show(L, -1));
  lua_settop(L, 0);
  run(L, "local function mk() local a, b = 1, 2; return function() return a end,"
         " function() return b end end; capi_f1, capi_f2 = mk()");
  lua_getglobal(L, "capi_f1");
  lua_getglobal(L, "capi_f2");
  say("upvalueid distinct %d ", lua_upvalueid(L, 1, 1) != lua_upvalueid(L, 2, 1));
  lua_upvaluejoin(L, 1, 1, 2, 1);
  say("joined %d ", lua_upvalueid(L, 1, 1) == lua_upvalueid(L, 2, 1));
  lua_call(L, 0, 1);
  say("f1 now %s\n", show(L, -1));
  lua_settop(L, 0);
  luaL_requiref(L, "capi_mini", open_minilib, 1);
  lua_pop(L, 1);
  run(L, "print('requiref', capi_mini.double(21), package.loaded.capi_mini == capi_mini)");
  lua_register(L, "capi_registered", f_double);
  run(L, "print('register', capi_registered(4))");
}

/* ---- userdata, user values, luaL_*udata ---- */

typedef struct { int x, y; } Point;

static int point_tostring(lua_State *L) {
  Point *p = (Point *)luaL_checkudata(L, 1, "capi.Point");
  lua_pushfstring(L, "Point(%d, %d)", p->x, p->y);
  return 1;
}

static void t_userdata(lua_State *L) {
  Point *p;
  void *raw;
  {
    int first = luaL_newmetatable(L, "capi.Point");
    say("newmetatable %d %d ", first, luaL_newmetatable(L, "capi.Point"));
  }
  lua_pop(L, 1);
  lua_pushcfunction(L, point_tostring);
  lua_setfield(L, -2, "__tostring");
  lua_pop(L, 1);
  p = (Point *)lua_newuserdatauv(L, sizeof(Point), 2);
  p->x = 3; p->y = 4;
  luaL_setmetatable(L, "capi.Point");
  say("testudata %d %d ", luaL_testudata(L, -1, "capi.Point") == p,
      luaL_testudata(L, -1, "nope") == NULL);
  say("checkudata %d\n", luaL_checkudata(L, -1, "capi.Point") == p);
  lua_pushstring(L, "uv1");
  say("setiuservalue %d ", lua_setiuservalue(L, -2, 1));
  lua_pushstring(L, "uv2");
  say("%d ", lua_setiuservalue(L, -2, 2));
  lua_pushstring(L, "uv3");
  say("%d ", lua_setiuservalue(L, -2, 3));
  {
    int ty = lua_getiuservalue(L, -1, 2);
    say("getiuservalue %d %s ", ty, show(L, -1));
    lua_pop(L, 1);
    ty = lua_getiuservalue(L, -1, 3);
    say("%d %s\n", ty, show(L, -1));
    lua_pop(L, 1);
  }
  luaL_tolstring(L, -1, NULL);
  say("tolstring %s ", show(L, -1));
  lua_pop(L, 1);
  {
    int ty = luaL_getmetafield(L, -1, "__name");
    say("getmetafield %d %s ", ty, show(L, -1));
    lua_pop(L, 1);
    ty = luaL_callmeta(L, -1, "__tostring");
    say("callmeta %d %s\n", ty, show(L, -1));
  }
  lua_settop(L, 0);
  raw = lua_newuserdata(L, 16);
  lua_pushinteger(L, 5);
  lua_setuservalue(L, -2);
  {
    int ty = lua_getuservalue(L, -1);
    say("newuserdata %d getuservalue %d %s\n", raw != NULL, ty, show(L, -1));
  }
  lua_settop(L, 0);
}

/* ---- luaL_Buffer ---- */

static void t_buffer(lua_State *L) {
  luaL_Buffer b;
  char *p;
  int i;
  luaL_buffinit(L, &b);
  luaL_addchar(&b, 'a');
  luaL_addlstring(&b, "bcd", 2);
  luaL_addstring(&b, "-x-");
  lua_pushinteger(L, 77);
  luaL_addvalue(&b);
  luaL_addgsub(&b, "a.b.c", ".", "::");
  say("bufflen %zu buffaddr %.4s ", luaL_bufflen(&b), luaL_buffaddr(&b));
  luaL_buffsub(&b, 2);
  p = luaL_prepbuffer(&b);
  memcpy(p, "PQ", 2);
  luaL_addsize(&b, 2);
  luaL_pushresult(&b);
  say("result %s\n", show(L, -1));
  lua_pop(L, 1);
  /* Overflow from the initial buffer into a box. */
  luaL_buffinit(L, &b);
  for (i = 0; i < 3000; i++) luaL_addchar(&b, (char)('a' + i % 26));
  p = luaL_prepbuffsize(&b, 100000);
  memset(p, 'z', 100000);
  luaL_addsize(&b, 100000);
  luaL_pushresult(&b);
  {
    size_t n;
    const char *s = lua_tolstring(L, -1, &n);
    say("big %zu %.5s %c\n", n, s + 2990, s[n - 1]);
  }
  lua_pop(L, 1);
  p = luaL_buffinitsize(L, &b, 5000);
  memset(p, 'q', 5000);
  luaL_pushresultsize(&b, 5000);
  say("buffinitsize %llu ", (unsigned long long)lua_rawlen(L, -1));
  lua_pop(L, 1);
  say("gsub %s\n", luaL_gsub(L, "x+y+z", "+", "<>"));
  lua_pop(L, 1);
  {
    char *ext = (char *)malloc(6);
    memcpy(ext, "extrn", 6);
    lua_pushexternalstring(L, ext, 5, NULL, NULL);
    say("externalstring %s\n", show(L, -1));
    lua_pop(L, 1);
    free(ext);
  }
}

/* ---- pushfstring and pushvfstring ---- */

static const char *vf(lua_State *L, const char *fmt, ...) {
  const char *s;
  va_list ap;
  va_start(ap, fmt);
  s = lua_pushvfstring(L, fmt, ap);
  va_end(ap);
  return s;
}

static void t_format(lua_State *L) {
  say("%s\n", lua_pushfstring(L, "[%s|%d|%I|%f|%c|%U|%%]", "str", -12,
                              (LUAI_UACINT)1234567890123LL, 2.5, 'Z', 0x20AC));
  say("%s\n", vf(L, "<%s %d %f>", "v", 7, 0.125));
  lua_settop(L, 0);
}

/* ---- the registry and references ---- */

static void t_refs(lua_State *L) {
  int r1, r2, rn;
  lua_pushstring(L, "one");
  r1 = luaL_ref(L, LUA_REGISTRYINDEX);
  lua_pushstring(L, "two");
  r2 = luaL_ref(L, LUA_REGISTRYINDEX);
  lua_pushnil(L);
  rn = luaL_ref(L, LUA_REGISTRYINDEX);
  lua_rawgeti(L, LUA_REGISTRYINDEX, r1);
  lua_rawgeti(L, LUA_REGISTRYINDEX, r2);
  say("refs distinct %d refnil %d values %s ", r1 != r2, rn == LUA_REFNIL,
      show(L, -2));
  say("%s ", show(L, -1));
  luaL_unref(L, LUA_REGISTRYINDEX, r1);
  lua_pushstring(L, "three");
  say("reused %d\n", luaL_ref(L, LUA_REGISTRYINDEX) == r1);
  luaL_unref(L, LUA_REGISTRYINDEX, LUA_NOREF);
  lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
  say("ridx mainthread %s ", show(L, -1));
  {
    int ismain = lua_pushthread(L);
    say("pushthread main %d same %d\n", ismain, lua_rawequal(L, -1, -2));
  }
  lua_settop(L, 0);
}

/* ---- luaL_Stream ---- */

static int stream_close(lua_State *L) {
  luaL_Stream *p = (luaL_Stream *)luaL_checkudata(L, 1, LUA_FILEHANDLE);
  int ok = (fclose(p->f) == 0);
  say("stream closef\n");
  return luaL_fileresult(L, ok, NULL);
}

static int f_openstream(lua_State *L) {
  const char *name = luaL_checkstring(L, 1);
  luaL_Stream *p = (luaL_Stream *)lua_newuserdatauv(L, sizeof(luaL_Stream), 0);
  p->closef = NULL;
  luaL_setmetatable(L, LUA_FILEHANDLE);
  p->f = fopen(name, "w+");
  if (p->f == NULL) return luaL_fileresult(L, 0, name);
  p->closef = stream_close;
  return 1;
}

static void t_stream(lua_State *L) {
  lua_register(L, "capi_openstream", f_openstream);
  run(L, "local f = capi_openstream(os.tmpname())\n"
         "f:write('hello ', 42, '\\n') f:seek('set') print('stream', f:read('l'))\n"
         "print('stream type', io.type(f)) f:close() print('stream type', io.type(f))\n"
         "print('stream fail', capi_openstream('/nonexistent/dir/x'))");
}

/* ---- the extra space ---- */

static void t_extraspace(lua_State *L) {
  lua_State *co;
  memcpy(lua_getextraspace(L), "EXTRA!!", 8);
  co = lua_newthread(L);
  say("extraspace %d copied %s\n", (int)LUA_EXTRASPACE,
      (char *)lua_getextraspace(co));
  memcpy(lua_getextraspace(co), "thread", 7);
  say("independent %s\n", (char *)lua_getextraspace(L));
  lua_pop(L, 1);
}

/* ---- load and dump ---- */

typedef struct { const char *parts[4]; int i; } Pieces;

static const char *reader(lua_State *L, void *ud, size_t *size) {
  Pieces *p = (Pieces *)ud;
  (void)L;
  if (p->parts[p->i] == NULL) { *size = 0; return NULL; }
  *size = strlen(p->parts[p->i]);
  return p->parts[p->i++];
}

typedef struct { char data[4096]; size_t n; int calls; } Sink;

static int writer(lua_State *L, const void *p, size_t sz, void *ud) {
  Sink *s = (Sink *)ud;
  (void)L;
  if (s->n + sz > sizeof s->data) return 1;
  memcpy(s->data + s->n, p, sz);
  s->n += sz;
  s->calls++;
  return 0;
}

static void t_load(lua_State *L) {
  Pieces pc = {{"local a, b = ...; ", "return a + b, ", "'chunked'", NULL}, 0};
  static Sink sink;
  int st = lua_load(L, reader, &pc, "=pieces", NULL);
  say("load %d ", st);
  lua_pushinteger(L, 3);
  lua_pushinteger(L, 4);
  lua_call(L, 2, LUA_MULTRET);
  stack(L, "loaded");
  lua_settop(L, 0);
  luaL_loadstring(L, "return 'dumped', ...");
  sink.n = 0;
  say("dump %d ", lua_dump(L, writer, &sink, 1));
  say("bytes>0 %d sig %d\n", sink.n > 0, memcmp(sink.data, LUA_SIGNATURE, 4) == 0);
  lua_pop(L, 1);
  st = luaL_loadbufferx(L, sink.data, sink.n, "=bin", "t");
  say("binary as text %d %s\n", st, show(L, -1));
  lua_pop(L, 1);
  st = luaL_loadbuffer(L, sink.data, sink.n, "=bin");
  lua_pushstring(L, "x");
  lua_call(L, 1, 2);
  say("binary %d %s ", st, show(L, -2));
  say("%s\n", show(L, -1));
  lua_settop(L, 0);
  /* 'B' loads from a fixed buffer: code and long strings stay in 'sink' */
  luaL_loadstring(L, "local s = 'a string longer than forty bytes, used in place'\n"
                     "return s, #s");
  sink.n = 0;
  sink.calls = 0;
  st = lua_dump(L, writer, &sink, 0);
  say("dump %d calls %d ", st, sink.calls);
  lua_pop(L, 1);
  st = luaL_loadbufferx(L, sink.data, sink.n, "=fixed", "B");
  lua_call(L, 0, 2);
  say("fixed %d %s ", st, show(L, -2));
  say("%s\n", show(L, -1));
  lua_settop(L, 0);
  st = luaL_loadstring(L, "return +");
  say("syntax %d %s\n", st, show(L, -1));
  lua_pop(L, 1);
  {
    char path[] = "/tmp/capiXXXXXX";
    FILE *f;
    int fd = mkstemp(path);
    f = fdopen(fd, "w");
    fputs("#!shebang line\nreturn 'from file', ...\n", f);
    fclose(f);
    st = luaL_loadfilex(L, path, "bt");
    lua_pushinteger(L, 1);
    lua_call(L, 1, 2);
    say("loadfilex %d %s ", st, show(L, -2));
    say("%s ", show(L, -1));
    lua_settop(L, 0);
    st = luaL_loadfile(L, path);
    lua_pop(L, 1);
    say("loadfile %d dofile %d ", st, luaL_dofile(L, path));
    lua_settop(L, 0);
    remove(path);
    st = luaL_loadfile(L, path);
    say("missing %d\n", st == LUA_ERRFILE);
    lua_pop(L, 1);
  }
}

/* ---- the debug interface and hooks ---- */

static int hook_lines;
static int hook_calls;
static int hook_counts;

static void hook(lua_State *L, lua_Debug *ar) {
  switch (ar->event) {
    case LUA_HOOKLINE: hook_lines++; break;
    case LUA_HOOKCALL: case LUA_HOOKTAILCALL: hook_calls++; break;
    case LUA_HOOKCOUNT: hook_counts++; break;
    default: break;
  }
  (void)L;
}

static int f_inspect(lua_State *L) {
  lua_Debug ar;
  const char *name;
  if (!lua_getstack(L, 1, &ar)) return 0;
  lua_getinfo(L, "nSltur", &ar);
  say("getinfo what=%s src=%s line=%d def=%d-%d nups=%d nparams=%d vararg=%d "
      "tail=%d short_src=%s\n", ar.what, ar.source, ar.currentline,
      ar.linedefined, ar.lastlinedefined, ar.nups, ar.nparams, ar.isvararg,
      ar.istailcall, ar.short_src);
  name = lua_getlocal(L, &ar, 1);
  say("getlocal 1 %s=%s ", name, show(L, -1));
  lua_pop(L, 1);
  lua_pushinteger(L, 1000);
  say("setlocal %s ", lua_setlocal(L, &ar, 1));
  say("getlocal 9 %s\n", lua_getlocal(L, &ar, 9) ? "yes" : "NULL");
  lua_getglobal(L, "capi_dbgf");
  lua_getinfo(L, ">S", &ar);
  say("getinfo > what=%s line=%d\n", ar.what, ar.linedefined);
  lua_getglobal(L, "capi_dbgf");
  say("getlocal(func) %s\n", lua_getlocal(L, NULL, 1));
  lua_pop(L, 1);
  return 0;
}

static void t_debug(lua_State *L) {
  lua_register(L, "capi_inspect", f_inspect);
  run(L, "function capi_dbgf(a, b, ...)\n  capi_inspect()\n  return a\nend\n"
         "print('after setlocal', capi_dbgf(1, 2))");
  lua_sethook(L, hook, LUA_MASKLINE | LUA_MASKCALL | LUA_MASKCOUNT, 1);
  say("gethook %d mask %d count %d\n", lua_gethook(L) == hook,
      lua_gethookmask(L), lua_gethookcount(L));
  run(L, "local s = 0\nfor i = 1, 3 do\n  s = s + i\nend\nreturn tostring(s)");
  lua_sethook(L, NULL, 0, 0);
  say("hooks lines>0 %d calls>0 %d counts>0 %d gethook %d\n", hook_lines > 0,
      hook_calls > 0, hook_counts > 0, lua_gethook(L) == NULL);
  run(L, "print('traceback?', debug.traceback('m', 1):match('^m\\nstack traceback:') ~= nil)");
  luaL_traceback(L, L, "tb", 0);
  say("luaL_traceback starts %d\n", strncmp(lua_tostring(L, -1), "tb\nstack traceback:", 19) == 0);
  lua_pop(L, 1);
}

/* ---- warnings ---- */

static void warnf(void *ud, const char *msg, int tocont) {
  say("warn[%s]%s%s", (const char *)ud, msg, tocont ? "" : "\n");
}

static void t_warn(lua_State *L) {
  lua_setwarnf(L, warnf, "ud");
  lua_warning(L, "one ", 1);
  lua_warning(L, "two", 0);
  run(L, "warn('from ', 'lua')");
  lua_setwarnf(L, NULL, NULL);
  lua_warning(L, "dropped", 0);
}

/* ---- errors: every route in PROMPT.md §6.3 that a C function can take ---- */

static int f_error(lua_State *L) {
  lua_pushstring(L, "plain error");
  return lua_error(L);
}

static int f_lerror(lua_State *L) {
  return luaL_error(L, "luaL_error %d %s %f", 7, "x", 1.5);
}

static int f_argerror(lua_State *L) {
  return luaL_argerror(L, 2, "custom");
}

static int f_typeerror(lua_State *L) {
  return luaL_typeerror(L, 1, "widget");
}

static int f_checks(lua_State *L) {
  static const char *const opts[] = {"alpha", "beta", NULL};
  size_t len;
  int o = luaL_checkoption(L, 1, "beta", opts);
  lua_Integer i = luaL_optinteger(L, 2, -1);
  lua_Number n = luaL_optnumber(L, 3, 0.5);
  const char *s = luaL_optlstring(L, 4, "dflt", &len);
  const char *s2 = luaL_optstring(L, 5, "d2");
  luaL_checkany(L, 6);
  luaL_checktype(L, 6, LUA_TTABLE);
  luaL_checkstack(L, 10, "no room");
  luaL_argcheck(L, i < 100, 2, "too big");
  luaL_argexpected(L, n >= 0, 3, "non-negative");
  luaL_checkversion(L);
  lua_pushfstring(L, "%d %I %f %s/%d %s %s", o, (LUAI_UACINT)i, n, s, (int)len,
                  s2, luaL_typename(L, 6));
  (void)luaL_checknumber(L, 3);
  return 1;
}

static int f_misc(lua_State *L) {
  size_t len;
  const char *s = luaL_checklstring(L, 1, &len);
  lua_Integer n = luaL_opt(L, luaL_checkinteger, 2, 6);
  luaL_checkversion_(L, LUA_VERSION_NUM, LUAL_NUMSIZES);
  luaL_newlibtable(L, minilib);
  luaL_getmetatable(L, "capi.Point");
  lua_pushfstring(L, "%s/%d %I %I %s", s, (int)len, (LUAI_UACINT)n,
                  (LUAI_UACINT)luaL_intop(+, LUA_MAXINTEGER, 1),
                  luaL_typename(L, -1));
  luaL_pushfail(L);
  return 2;
}

static int f_where(lua_State *L) {
  luaL_where(L, 1);
  return 1;
}

static int f_results(lua_State *L) {
  int n;
  errno = 0; /* luaL_execresult reports errno when it is set */
  n = luaL_execresult(L, 0);
  n += luaL_execresult(L, 3 << 8);
  return n + luaL_fileresult(L, 1, NULL);
}

static void t_errors(lua_State *L) {
  lua_register(L, "capi_error", f_error);
  lua_register(L, "capi_lerror", f_lerror);
  lua_register(L, "capi_argerror", f_argerror);
  lua_register(L, "capi_typeerror", f_typeerror);
  lua_register(L, "capi_checks", f_checks);
  lua_register(L, "capi_where", f_where);
  lua_register(L, "capi_misc", f_misc);
  lua_register(L, "capi_results", f_results);
  run(L, "print(pcall(capi_error))\nprint(pcall(capi_lerror))\n"
         "print(pcall(capi_argerror))\nprint(pcall(capi_typeerror, 1))\n"
         "print(pcall(capi_checks, 'alpha', 5, 2.5, 'str', nil, {}))\n"
         "print(pcall(capi_checks, nil, nil, nil, nil, nil, {}))\n"
         "print(pcall(capi_checks, 'gamma'))\n"
         "print(pcall(capi_checks, 'alpha', 500, 1, 's', 's', {}))\n"
         "print(pcall(capi_checks, 'alpha', 5, -1, 's', 's', {}))\n"
         "print(pcall(capi_checks, 'alpha', 5, 1, 's', 's'))\n"
         "print(pcall(capi_checks, 'alpha', 'x'))\n"
         "print(capi_where())\nprint(capi_results())\n"
         "print(capi_misc('ab'))\nprint(capi_misc('cd', 9))\nprint(pcall(capi_misc, {}))");
  /* Lua -> C -> Lua -> error, caught in C. */
  lua_getglobal(L, "pcall");
  luaL_loadstring(L, "error({code = 5})");
  {
    int st = lua_pcall(L, 1, 2, 0);
    say("pcall from C %d %s %s\n", st, show(L, -2), show(L, -1));
    lua_settop(L, 0);
    luaL_loadstring(L, "local t = setmetatable({}, {__index = function() error('deep', 0) end}) return t.x");
    st = lua_pcall(L, 0, 0, 0);
    say("pcall status %d %s ", st, show(L, -1));
    lua_settop(L, 0);
    lua_pushcfunction(L, f_where); /* a message handler */
    luaL_loadstring(L, "error('handled')");
    st = lua_pcall(L, 0, 0, 1);
    say("msgh %d %s\n", st, show(L, -1));
  }
  lua_settop(L, 0);
  luaL_loadstring(L, "error(setmetatable({}, {__tostring = function() return 'TS' end}))");
  lua_pcall(L, 0, 0, 0);
  say("error object tolstring %s\n", luaL_tolstring(L, -1, NULL));
  lua_settop(L, 0);
}

/* ---- to-be-closed slots ---- */

static void t_close(lua_State *L) {
  run(L, "capi_closemt = {__close = function(o, e) print('closed', o.name, e) end}");
  lua_newtable(L);
  lua_pushstring(L, "slot");
  lua_setfield(L, -2, "name");
  lua_getglobal(L, "capi_closemt");
  lua_setmetatable(L, -2);
  lua_toclose(L, -1);
  lua_closeslot(L, -1);
  say("closeslot done top %d\n", lua_gettop(L));
  lua_settop(L, 0);
  lua_newtable(L);
  lua_pushstring(L, "settop");
  lua_setfield(L, -2, "name");
  lua_getglobal(L, "capi_closemt");
  lua_setmetatable(L, -2);
  lua_toclose(L, -1);
  lua_settop(L, 0);
}

/* ---- coroutines, yields from C, continuations ---- */

static int k_after_yield(lua_State *L, int status, lua_KContext ctx) {
  say("continuation status %d ctx %d top %d\n", status == LUA_YIELD, (int)ctx,
      lua_gettop(L));
  lua_pushstring(L, "k-done");
  return 1;
}

static int f_yielder(lua_State *L) {
  lua_pushstring(L, "yielded-from-C");
  return lua_yieldk(L, 1, 21, k_after_yield);
}

static int f_yield_plain(lua_State *L) {
  return lua_yield(L, lua_gettop(L));
}

static int k_callk(lua_State *L, int status, lua_KContext ctx) {
  say("callk continuation %d ctx %d %s\n", status == LUA_YIELD, (int)ctx,
      show(L, -1));
  return 1;
}

static int f_callk(lua_State *L) {
  lua_pushvalue(L, 1);
  lua_callk(L, 0, 1, 33, k_callk);
  return k_callk(L, LUA_OK, 33);
}

static int k_pcallk(lua_State *L, int status, lua_KContext ctx) {
  say("pcallk continuation status %d ctx %d %s\n", status, (int)ctx,
      show(L, -1));
  return 1;
}

static int f_pcallk(lua_State *L) {
  lua_pushvalue(L, 1);
  return k_pcallk(L, lua_pcallk(L, 0, 1, 0, 44, k_pcallk), 44);
}

static void t_coroutines(lua_State *L) {
  lua_State *co;
  int nres, st;
  lua_register(L, "capi_yielder", f_yielder);
  lua_register(L, "capi_yield", f_yield_plain);
  lua_register(L, "capi_callk", f_callk);
  lua_register(L, "capi_pcallk", f_pcallk);
  co = lua_newthread(L);
  say("isyieldable main %d co %d status %d\n", lua_isyieldable(L),
      lua_isyieldable(co), lua_status(co));
  luaL_loadstring(co, "local a = ...; local r = capi_yielder(); "
                      "local b, c = capi_yield(a + 1, 'two'); return r, b + c");
  lua_pushinteger(co, 10);
  st = lua_resume(co, L, 1, &nres);
  say("resume1 %d nres %d %s\n", st, nres, show(co, -1));
  lua_pop(co, nres);
  st = lua_resume(co, L, 0, &nres);
  say("resume2 %d nres %d %s %s status %d\n", st, nres, show(co, -2),
      show(co, -1), lua_status(co));
  lua_pop(co, nres);
  lua_pushinteger(co, 5);
  lua_pushinteger(co, 6);
  st = lua_resume(co, L, 2, &nres);
  say("resume3 %d nres %d %s %s\n", st, nres, show(co, -2), show(co, -1));
  lua_pop(co, nres);
  lua_pushinteger(co, 99);
  lua_xmove(co, L, 1);
  say("xmove %s\n", show(L, -1));
  lua_pop(L, 1);
  say("closethread %d\n", lua_closethread(co, L));
  luaL_loadstring(co, "error('in coroutine')");
  st = lua_resume(co, L, 0, &nres);
  say("error resume %d %s status %d ", st, show(co, -1), lua_status(co));
  say("resetthread %d\n", lua_resetthread(co));
  lua_pop(L, 1);
  run(L, "local co = coroutine.wrap(function() return capi_callk(function() "
         "return coroutine.yield('y1') end) end)\n"
         "print('callk', co()) print('callk', co('resumed'))\n"
         "co = coroutine.wrap(function() return capi_pcallk(function() "
         "coroutine.yield('y2'); error('after yield', 0) end) end)\n"
         "print('pcallk', co()) print('pcallk', co())\n"
         "co = coroutine.wrap(function() return capi_pcallk(function() "
         "return 'no yield' end) end)\n"
         "print('pcallk', co())\n"
         "co = coroutine.wrap(function() local t <close> = setmetatable({}, "
         "{__close = function() print('tbc closed in coroutine') end}); "
         "coroutine.yield(1); return 2 end)\n"
         "print('tbc', co()) print('tbc', co())");
}

/* ---- the collector ---- */

static void t_gc(lua_State *L) {
  int k, b;
  lua_gc(L, LUA_GCCOLLECT);
  k = lua_gc(L, LUA_GCCOUNT);
  b = lua_gc(L, LUA_GCCOUNTB);
  say("gc count>0 %d countb in range %d ", k > 0, b >= 0 && b < 1024);
  lua_gc(L, LUA_GCSTOP);
  say("running %d ", lua_gc(L, LUA_GCISRUNNING));
  lua_gc(L, LUA_GCRESTART);
  say("%d ", lua_gc(L, LUA_GCISRUNNING));
  say("step %d ", lua_gc(L, LUA_GCSTEP, 0) >= 0);
  say("gen<-inc %d ", lua_gc(L, LUA_GCGEN));
  say("inc<-gen %d ", lua_gc(L, LUA_GCINC));
  {
    int old = lua_gc(L, LUA_GCPARAM, LUA_GCPPAUSE, 150);
    say("param pause old>0 %d now %d\n", old > 0,
        lua_gc(L, LUA_GCPARAM, LUA_GCPPAUSE, old));
  }
  say("gc bad option %d\n", lua_gc(L, 12345));
}

/* ---- states: custom allocator, memory errors, panic, newstate ---- */

typedef struct { size_t live; size_t total; int fail; } Mem;

static void *counting_alloc(void *ud, void *ptr, size_t osize, size_t nsize) {
  Mem *m = (Mem *)ud;
  if (ptr == NULL) osize = 0;
  if (nsize == 0) {
    free(ptr);
    m->live -= osize;
    return NULL;
  }
  if (m->fail && nsize > osize) return NULL;
  ptr = realloc(ptr, nsize);
  if (ptr != NULL) { m->live += nsize - osize; m->total += nsize; }
  return ptr;
}

static jmp_buf panic_jmp;

static int on_panic(lua_State *L) {
  say("panic: %s\n", lua_tostring(L, -1));
  longjmp(panic_jmp, 1);
  return 0;
}

static int f_alloc_much(lua_State *L) {
  lua_createtable(L, 100000, 0);
  return 1;
}

static void t_states(void) {
  Mem m = {0, 0, 0};
  void *ud = NULL;
  lua_State *L = lua_newstate(counting_alloc, &m, luaL_makeseed(NULL));
  {
    int same = lua_getallocf(L, &ud) == counting_alloc;
    say("newstate %d live>0 %d getallocf %d ud %d version %.0f\n", L != NULL,
        m.live > 0, same, ud == &m, (double)lua_version(L));
  }
  luaL_openselectedlibs(L, ~0, 0);
  run(L, "local t = {} for i = 1, 1000 do t[i] = tostring(i) end");
  lua_pushcfunction(L, f_alloc_much);
  m.fail = 1;
  {
    int st = lua_pcall(L, 0, 0, 0);
    say("memerr %d %s\n", st == LUA_ERRMEM, show(L, -1));
  }
  m.fail = 0;
  lua_pop(L, 1);
  lua_setallocf(L, counting_alloc, &m);
  lua_atpanic(L, on_panic);
  if (setjmp(panic_jmp) == 0) {
    lua_pushstring(L, "unprotected");
    lua_error(L);
  }
  lua_close(L);
  say("after close live %zu total>0 %d\n", m.live, m.total > 0);
  L = luaL_newstate();
  say("luaL_newstate %d ", L != NULL);
  luaL_openselectedlibs(L, ~0, LUA_IOLIBK);
  lua_getglobal(L, "io");
  say("io loaded %d ", lua_istable(L, -1));
  lua_pop(L, 1);
  luaL_openlibs(L);
  lua_getglobal(L, "string");
  say("openlibs %d ", lua_istable(L, -1));
  say("alloc via luaL_alloc %d\n", lua_getallocf(L, NULL) == luaL_alloc);
  lua_close(L);
  L = luaL_newstate();
  luaL_requiref(L, "_G", luaopen_base, 1);
  luaL_requiref(L, LUA_LOADLIBNAME, luaopen_package, 1);
  luaL_requiref(L, LUA_COLIBNAME, luaopen_coroutine, 1);
  luaL_requiref(L, LUA_DBLIBNAME, luaopen_debug, 1);
  luaL_requiref(L, LUA_IOLIBNAME, luaopen_io, 1);
  luaL_requiref(L, LUA_MATHLIBNAME, luaopen_math, 1);
  luaL_requiref(L, LUA_OSLIBNAME, luaopen_os, 1);
  luaL_requiref(L, LUA_STRLIBNAME, luaopen_string, 1);
  luaL_requiref(L, LUA_TABLIBNAME, luaopen_table, 1);
  luaL_requiref(L, LUA_UTF8LIBNAME, luaopen_utf8, 1);
  say("luaopen_* top %d\n", lua_gettop(L));
  lua_close(L);
}

static int f_run(lua_State *L) {
  say("ident %d\n", strncmp(lua_ident, "$LuaVersion: ", 13) == 0);
  t_stack(L);
  t_ops(L);
  t_tables(L);
  t_closures(L);
  t_userdata(L);
  t_buffer(L);
  t_format(L);
  t_refs(L);
  t_stream(L);
  t_extraspace(L);
  t_load(L);
  t_debug(L);
  t_warn(L);
  t_errors(L);
  t_close(L);
  t_coroutines(L);
  t_gc(L);
  t_states();
  say("done\n");
  return 0;
}

int luaopen_capi(lua_State *L) {
  luaL_checkversion(L);
  lua_newtable(L);
  lua_pushcfunction(L, f_run);
  lua_setfield(L, -2, "run");
  return 1;
}
