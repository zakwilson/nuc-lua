#include <lua.h>
#include <lauxlib.h>

#include <sys/select.h>

static int f_mayi(lua_State* L) {
  fd_set s;
  struct timeval tm = {0,0};
  if(lua_isnumber(L, 1)) {
    tm.tv_sec = (int)lua_tonumber(L, 1);
    tm.tv_usec = (int)(lua_tonumber(L, 1) * 1000000) % 1000000;
    if(tm.tv_usec >= 1000000) {
      tm.tv_usec -= 1000000;
      ++tm.tv_sec;
    }
  }
  FD_ZERO(&s);
  FD_SET(0, &s);
  lua_pushboolean(L, select(1, &s, NULL, NULL, &tm));
  return 1;
}

static const struct luaL_Reg regs[] = {
  {"mayi", f_mayi},
  {NULL, NULL}
};

int luaopen_mayi(lua_State* L) {
#if LUA_VERSION_NUM < 502
  luaL_register(L, "mayi", regs);
#else
  lua_newtable(L);
  luaL_setfuncs(L, regs, 0);
#endif
  return 1;
}
