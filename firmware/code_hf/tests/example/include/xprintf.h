// Brief  : Formatted output interface for the example firmware.
// Author : pango_lpenghan
// Rev    : 1.0
// Date   : 2026-10-13

#ifndef XPRINTF_H
#define XPRINTF_H

#include <stdarg.h>

/* 1: convert '\n' to CRLF in the output stream */
#define _CR_CRLF 0

#define xdev_out(func) xfunc_out = (void (*)(unsigned char))(func)

extern void (*xfunc_out)(unsigned char);
extern void xputc(char c);
extern void xputs(const char *str);
extern void xprintf(const char *fmt, ...);

#define DW_CHAR  sizeof(char)
#define DW_SHORT sizeof(short)
#define DW_LONG  sizeof(long)

#endif
