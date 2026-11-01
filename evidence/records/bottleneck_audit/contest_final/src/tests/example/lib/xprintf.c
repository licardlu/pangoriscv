// Brief  : Minimal formatted output for the example firmware (freestanding).
// Author : pango_lpenghan
// Rev    : 1.0
// Date   : 2026-10-13
//
// Conversions: %d %i %u %x %X %p %c %s %% with the '-' and '0' flags and a
// decimal field width.  No floating point and no libc: the single output
// primitive is the xfunc_out function pointer installed by the platform.

#include "../include/xprintf.h"

#define DIGITS 32

void (*xfunc_out)(unsigned char);

void xputc(char c)
{
    if (xfunc_out == 0) return;
    xfunc_out((unsigned char)c);
#if _CR_CRLF
    if (c == '\n') xfunc_out((unsigned char)'\r');
#endif
}

void xputs(const char *str)
{
    if (str == 0) return;
    while (*str != '\0') xputc(*str++);
}

static void emit_digits(unsigned long value, unsigned int base, int upper,
                        int width, char pad, int left)
{
    const char *table = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char digits[DIGITS];
    int len = 0;
    int i;

    do {
        digits[len++] = table[value % base];
        value /= base;
    } while (value != 0 && len < DIGITS);

    if (!left) {
        for (i = len; i < width; i++) xputc(pad);
    }
    for (i = len - 1; i >= 0; i--) xputc(digits[i]);
    if (left) {
        for (i = len; i < width; i++) xputc(' ');
    }
}

static void emit_signed(long value, int width, char pad, int left)
{
    unsigned long magnitude;

    if (value < 0) {
        xputc('-');
        if (width > 0) width--;
        magnitude = (unsigned long)(-(value + 1)) + 1UL;
    } else {
        magnitude = (unsigned long)value;
    }
    emit_digits(magnitude, 10, 0, width, pad, left);
}

static void emit_string(const char *s, int width, int left)
{
    int len = 0;
    int i;

    if (s == 0) s = "(null)";
    while (s[len] != '\0') len++;

    if (!left) {
        for (i = len; i < width; i++) xputc(' ');
    }
    while (*s != '\0') xputc(*s++);
    if (left) {
        for (i = len; i < width; i++) xputc(' ');
    }
}

void xprintf(const char *fmt, ...)
{
    va_list ap;

    if (fmt == 0) return;
    va_start(ap, fmt);

    while (*fmt != '\0') {
        int left = 0;
        int zero = 0;
        int width = 0;

        if (*fmt != '%') {
            xputc(*fmt++);
            continue;
        }
        fmt++;
        if (*fmt == '%') {
            xputc('%');
            fmt++;
            continue;
        }
        for (;;) {
            if (*fmt == '-') { left = 1; fmt++; }
            else if (*fmt == '0') { zero = 1; fmt++; }
            else if (*fmt == '+' || *fmt == ' ' || *fmt == '#') { fmt++; }
            else break;
        }
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }
        while (*fmt == 'l' || *fmt == 'h') fmt++;   /* length modifiers: ignored */

        switch (*fmt) {
        case 'd':
        case 'i':
            emit_signed((long)va_arg(ap, int), width, zero ? '0' : ' ', left);
            break;
        case 'u':
            emit_digits((unsigned long)va_arg(ap, unsigned int), 10, 0,
                        width, zero ? '0' : ' ', left);
            break;
        case 'x':
            emit_digits((unsigned long)va_arg(ap, unsigned int), 16, 0,
                        width, zero ? '0' : ' ', left);
            break;
        case 'X':
            emit_digits((unsigned long)va_arg(ap, unsigned int), 16, 1,
                        width, zero ? '0' : ' ', left);
            break;
        case 'p':
            xputc('0');
            xputc('x');
            emit_digits((unsigned long)(unsigned int)va_arg(ap, void *), 16, 0, 8, '0', 0);
            break;
        case 'c':
            xputc((char)va_arg(ap, int));
            break;
        case 's':
            emit_string(va_arg(ap, const char *), width, left);
            break;
        case '\0':
            va_end(ap);
            return;
        default:
            xputc('%');
            xputc(*fmt);
            break;
        }
        if (*fmt != '\0') fmt++;
    }

    va_end(ap);
}
