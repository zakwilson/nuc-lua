/* ISSUE-037: a header names a struct it leaves incomplete, as lparser.h's BlockCnt. */
struct Block;
typedef struct Holder { struct Block *bl; int n; } Holder;
