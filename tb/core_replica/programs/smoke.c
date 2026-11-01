/* -----------------------------------------------------------------------------
 * smoke.c -- 新核 V1 自检程序
 *
 * 目的: 在没有任何 Cache / 预测器的情况下, 用最短路径覆盖 P04~P07 的验收点:
 *   ALU 全部运算、移位边界、M 扩展 (含除零/溢出)、访存六种宽度、
 *   store->load 紧邻、分支六种条件、jal/jalr、CSR 读写、ecall 例外。
 *
 * 约定: 任何一项不符就打印 FAIL 行; 全部通过打印 SMOKE PASS。
 *       期望值一律写成字面常量, 不用被测指令再算一遍。
 * -------------------------------------------------------------------------- */
#define MMIO(a) (*(volatile unsigned *)(a))

static void putc_(char c) {
    if (c == '\n') putc_('\r');
    while ((MMIO(0x10001004) & 0x00ff0000) == 0) { }
    MMIO(0x10001000) = (unsigned char)c;
}

static void puts_(const char *s) { while (*s) putc_(*s++); }

static void puthex(unsigned v) {
    int i;
    puts_("0x");
    for (i = 28; i >= 0; i -= 4) {
        unsigned d = (v >> i) & 0xf;
        putc_(d < 10 ? ('0' + d) : ('a' + d - 10));
    }
}

static int fails;

static void chk(int id, unsigned got, unsigned exp) {
    if (got != exp) {
        fails++;
        puts_("FAIL ");
        puthex((unsigned)id);
        puts_(" got ");
        puthex(got);
        puts_(" exp ");
        puthex(exp);
        putc_('\n');
    }
}

/* ------------------------------ 例外记录 --------------------------------- */
volatile unsigned g_cause, g_epc, g_tval, g_traps;

void trap_report(unsigned cause, unsigned epc, unsigned tval) {
    g_cause = cause;
    g_epc   = epc;
    g_tval  = tval;
    g_traps = g_traps + 1;
}

/* ------------------------------ M 扩展 ----------------------------------- */
static unsigned mulh_(int a, int b)   { unsigned r; __asm__ volatile("mulh %0,%1,%2"   : "=r"(r) : "r"(a), "r"(b)); return r; }
static unsigned mulhsu_(int a, unsigned b) { unsigned r; __asm__ volatile("mulhsu %0,%1,%2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static unsigned mulhu_(unsigned a, unsigned b) { unsigned r; __asm__ volatile("mulhu %0,%1,%2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static unsigned div_(int a, int b)    { unsigned r; __asm__ volatile("div %0,%1,%2"    : "=r"(r) : "r"(a), "r"(b)); return r; }
static unsigned divu_(unsigned a, unsigned b) { unsigned r; __asm__ volatile("divu %0,%1,%2" : "=r"(r) : "r"(a), "r"(b)); return r; }
static unsigned rem_(int a, int b)    { unsigned r; __asm__ volatile("rem %0,%1,%2"    : "=r"(r) : "r"(a), "r"(b)); return r; }
static unsigned remu_(unsigned a, unsigned b) { unsigned r; __asm__ volatile("remu %0,%1,%2" : "=r"(r) : "r"(a), "r"(b)); return r; }

static unsigned csrr_mcycle(void) { unsigned r; __asm__ volatile("csrr %0, mcycle" : "=r"(r)); return r; }

/* ------------------------------ 测试区 ----------------------------------- */
static volatile int  vi_a, vi_b;
static volatile unsigned char  buf8[16];
static volatile unsigned short buf16[16];
static volatile unsigned       buf32[16];

void leaf(void) { vi_a = 0x1234; }

int main(void) {
    unsigned r;
    unsigned i;

    puts_("REPLICA_BOOT\n");

    /* ---- 1. ALU 基本运算 ---- */
    vi_a = 5; vi_b = -7;
    chk(0x101, (unsigned)(vi_a + vi_b), 0xfffffffe);
    chk(0x102, (unsigned)(vi_a - vi_b), 12);
    chk(0x103, (unsigned)(vi_a & vi_b), 1);
    chk(0x104, (unsigned)(vi_a | vi_b), 0xfffffffd);
    chk(0x105, (unsigned)(vi_a ^ vi_b), 0xfffffffc);
    chk(0x106, (vi_a < vi_b) ? 1u : 0u, 0);
    chk(0x107, ((unsigned)vi_a < (unsigned)vi_b) ? 1u : 0u, 1);
    chk(0x108, (unsigned)(vi_a << 3), 40);
    chk(0x109, ((unsigned)vi_b) >> 1, 0x7ffffffc);
    chk(0x10a, (unsigned)(vi_b >> 1), 0xfffffffc);

    /* ---- 2. 立即数与 LUI ---- */
    chk(0x110, (unsigned)(123456 << 12), 0x1e240000);
    chk(0x111, (unsigned)(-2048), 0xfffff800);

    /* ---- 3. M 扩展 ---- */
    vi_a = -3; vi_b = 7;
    chk(0x120, (unsigned)(vi_a * vi_b), 0xffffffeb);
    chk(0x121, mulh_(vi_a, vi_b), 0xffffffff);
    chk(0x122, mulhsu_(-1, 0xffffffffu), 0xffffffff);
    chk(0x123, mulhu_(0xffffffffu, 0xffffffffu), 0xfffffffe);
    chk(0x124, div_(vi_a, vi_b), 0);
    chk(0x125, rem_(vi_a, vi_b), 0xfffffffd);
    chk(0x126, div_(100, 7), 14);
    chk(0x127, rem_(100, 7), 2);
    chk(0x128, div_(7, 0), 0xffffffff);
    chk(0x129, rem_(7, 0), 7);
    chk(0x12a, div_((int)0x80000000, -1), 0x80000000);
    chk(0x12b, rem_((int)0x80000000, -1), 0);
    chk(0x12c, divu_(0xffffffffu, 2), 0x7fffffff);
    chk(0x12d, remu_(0xffffffffu, 16), 15);

    /* ---- 4. 访存: 六种宽度 + store->load 紧邻 ---- */
    for (i = 0; i < 16; i++) { buf8[i] = 0; buf16[i] = 0; buf32[i] = 0; }

    buf8[3]  = 0xA5;
    chk(0x130, buf8[3], 0xA5);
    chk(0x131, (unsigned)(signed char)buf8[3], 0xffffffa5);

    buf16[2] = 0xBEEF;
    chk(0x132, buf16[2], 0xBEEF);
    chk(0x133, (unsigned)(short)buf16[2], 0xffffbeef);

    buf32[1] = 0x12345678;
    chk(0x134, buf32[1], 0x12345678);

    /* store -> load 紧邻, 检验 RAM 前递 */
    buf32[2] = 0xDEADBEEF;
    r = buf32[2];
    chk(0x135, r, 0xDEADBEEF);

    buf8[5] = 0x11;
    chk(0x136, buf8[5], 0x11);

    /* ---- 5. 分支 ---- */
    r = 0;
    if (vi_a == -3) r |= 1;
    if (vi_a != 7)  r |= 2;
    if (vi_a <  7)  r |= 4;
    if (vi_a <= -3) r |= 8;
    if ((unsigned)vi_a > 7u) r |= 16;
    chk(0x140, r, 1 | 2 | 4 | 8 | 16);

    /* ---- 6. jalr ---- */
    r = 0;
    leaf();
    r = (unsigned)vi_a;
    chk(0x141, r, 0x1234);

    /* ---- 7. CSR ---- */
    {
        unsigned t0 = csrr_mcycle();
        for (i = 0; i < 100; i++) { __asm__ volatile("nop"); }
        unsigned t1 = csrr_mcycle();
        chk(0x150, (t1 > t0) ? 1u : 0u, 1);

        __asm__ volatile("csrw mstatus, %0" :: "r"(0x1800u));
        unsigned s2;
        __asm__ volatile("csrr %0, mstatus" : "=r"(s2));
        chk(0x151, s2 & 0x1800u, 0x1800u);
        __asm__ volatile("csrw mstatus, %0" :: "r"(0u));
    }

    /* ---- 8. ecall 例外 ---- */
    g_traps = 0;
    __asm__ volatile("ecall");
    chk(0x160, g_traps, 1);
    chk(0x161, g_cause, 11);

    /* ---- 9. 有符号 / 无符号比较边界 ---- */
    chk(0x170, (0x7fffffffu < 0x80000000u) ? 1u : 0u, 1);
    chk(0x171, ((int)0x7fffffff < (int)0x80000000) ? 1u : 0u, 0);

    if (fails == 0) puts_("SMOKE PASS\n");
    else            { puts_("SMOKE FAIL count="); puthex((unsigned)fails); putc_('\n'); }

    for (;;) { }
    return 0;
}
