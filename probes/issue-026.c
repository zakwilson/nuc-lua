#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include "issue-026.h"
void die (const char *fmt, ...) {
  va_list ap; va_start(ap, fmt); vprintf(fmt, ap); va_end(ap);
  exit(0);
}
