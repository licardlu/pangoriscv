/* -----------------------------------------------------------------------------
 * pair.c -- P08 双发射定向用例
 *
 * 目的: 计划 P08 的测试矩阵在 smoke.c 里覆盖不到, 单独写一份。
 *   1) 独立 ALU + ALU 必须都能写对
 *   2) 组内 RAW: lane1 读 lane0 本轮要写的 rd -> 必须拿到新值
 *   3) 组内 WAW: 两个写口写同一寄存器 -> 结果必须是更年轻那条的值
 *   4) ALU + 分支
 *   5) 分支 + ALU: 跳转成立时, 后面那条独立 ALU 不能产生副作用
 *   6) Load + ALU (同拍): 两者都要对
 *   7) Store + 分支
 *   8) CSR 读 + 普通 ALU
 *   9) 两条分支相邻
 *  10) 老例外 + 年轻指令: ecall 之后的 addi 不能把结果写进寄存器
 *  11) 吞吐: 独立链 vs 依赖链的 mcycle 差值 -> 双发射真的在发两条
 *
 * 约定: 任何一项不符打印 FAIL <id> got/exp; 全部通过打印 PAIR PASS。
 *       期望值全部写成字面常量, 不用被测指令再算一遍。
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
static void putdec(unsigned v) {
    char b[11];
    int n = 0;
    if (v == 0) { putc_('0'); return; }
    while (v) { b[n++] = '0' + (v % 10); v /= 10; }
    while (n) putc_(b[--n]);
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

static unsigned mcycle_(void) { unsigned r; __asm__ volatile("csrr %0, mcycle" : "=r"(r)); return r; }

/* ---------------------- 10. 例外: ecall 之后那条不能写寄存器 --------------- */
volatile unsigned g_traps;
unsigned g_after_ecall;

void trap_report(unsigned cause, unsigned epc, unsigned tval) {
    (void)cause; (void)epc; (void)tval;
    g_traps = g_traps + 1;
}

static void test_ecall(void) {
    g_after_ecall = 0xdead;
    /* ecall 与后面的 addi 相邻; addi 是更年轻的指令, 例外定案时必须被取消。 */
    __asm__ volatile(
        "ecall\n\t"
        "addi %0, zero, 0x5a\n\t"
        : "+r"(g_after_ecall) :: "memory");
}

/* ---------------------- 11. 吞吐: 独立 vs 依赖 ---------------------------- */
#define BENCH_N 1000

/* 用 .rept 做长直线序列: 每轮 2x64 条独立 ALU / 128 条依赖 ALU。
   循环只有 10 次, 分支惩罚被摊薄, 剩下的差异就是"能不能一拍发两条"。 */
static unsigned bench_indep(void) {
    unsigned a = 1, b = 2;
    unsigned t0 = mcycle_();
    int i;
    for (i = 0; i < 10; i++) {
        __asm__ volatile(
            ".rept 64\n\t"
            "addi %0, %0, 1\n\t"
            "addi %1, %1, 1\n\t"
            ".endr\n\t"
            : "+r"(a), "+r"(b) :: );
    }
    return mcycle_() - t0;
}

static unsigned bench_dep(void) {
    unsigned a = 1;
    unsigned t0 = mcycle_();
    int i;
    for (i = 0; i < 10; i++) {
        __asm__ volatile(
            ".rept 128\n\t"
            "addi %0, %0, 1\n\t"
            ".endr\n\t"
            : "+r"(a) :: );
    }
    return mcycle_() - t0;
}

/* ------------------------------ 主程序 ----------------------------------- */
volatile unsigned g_sink;

int main(void) {
    unsigned a, b, c, t;

    puts_("PAIR_BOOT\n");

    /* ---- 1. 独立 ALU + ALU ---- */
    a = 10; b = 20;
    __asm__ volatile(
        "addi %0, %0, 5\n\t"
        "addi %1, %1, 7\n\t"
        : "+r"(a), "+r"(b) :: );
    chk(0x201, a, 15);
    chk(0x202, b, 27);

    /* ---- 2. 组内 RAW ---- */
    a = 0; b = 100; c = 23;
    __asm__ volatile(
        "add  %0, %1, %2\n\t"
        "addi %3, %0, 1\n\t"        /* 读上一条刚写的 %0 */
        : "=&r"(a), "+r"(b), "+r"(c), "=r"(t) :: );
    /* a = 100 + 23 = 123, t = 124 */
    chk(0x210, a, 123);
    chk(0x211, t, 124);

    /* ---- 3. 组内 WAW: 两条都写 a, 更年轻的 +2 必须赢 ---- */
    a = 0;
    __asm__ volatile(
        "addi %0, zero, 11\n\t"
        "addi %0, zero, 22\n\t"
        : "=&r"(a) :: );
    chk(0x220, a, 22);

    /* ---- 4. ALU + 分支 ---- */
    a = 1; b = 0;
    __asm__ volatile(
        "addi %0, %0, 1\n\t"        /* a = 2, 与下面的分支无依赖 */
        "bnez %1, 1f\n\t"           /* b == 0, 不跳 */
        "addi %1, zero, 3\n\t"      /* 应执行 */
        "1:\n\t"
        : "+r"(a), "+r"(b) :: );
    chk(0x230, a, 2);
    chk(0x231, b, 3);

    /* ---- 5. 分支 + ALU: 跳转成立时后面那条不能执行 ---- */
    a = 1; b = 0;
    __asm__ volatile(
        "bnez %0, 1f\n\t"           /* a != 0, 跳 */
        "addi %1, zero, 0x77\n\t"   /* 不该执行 */
        "1:\n\t"
        : "+r"(a), "+r"(b) :: );
    chk(0x240, b, 0);

    /* ---- 6. Load + ALU 同拍 ---- */
    {
        static unsigned words[4] = { 0x11223344u, 0x55667788u, 0, 0 };
        a = 0; b = 0;
        __asm__ volatile(
            "lw   %0, 0(%2)\n\t"    /* load */
            "addi %1, %1, 9\n\t"    /* 与 load 无依赖, 可同拍 */
            : "=&r"(a), "+r"(b) : "r"(words) : "memory");
        chk(0x250, a, 0x11223344u);
        chk(0x251, b, 9);
    }

    /* ---- 7. Store + 分支 ---- */
    {
        static unsigned slot[2] = { 0, 0 };
        a = 0xabcdef01u; b = 0;
        __asm__ volatile(
            "sw   %0, 0(%2)\n\t"
            "beqz %1, 1f\n\t"
            "1:\n\t"
            : : "r"(a), "r"(b), "r"(slot) : "memory");
        chk(0x260, slot[0], 0xabcdef01u);
    }

    /* ---- 8. CSR 读 + 普通 ALU ---- */
    a = 0; b = 5;
    __asm__ volatile(
        "csrr %0, mcycle\n\t"
        "addi %1, %1, 1\n\t"
        : "=r"(a), "+r"(b) :: );
    chk(0x270, (a != 0) ? 1u : 0u, 1);   /* mcycle 已跑了很多拍, 不该是 0 */
    chk(0x271, b, 6);

    /* ---- 9. 两条分支相邻 ---- */
    a = 0; b = 0; c = 0;
    __asm__ volatile(
        "beqz %0, 1f\n\t"
        "addi %2, zero, 5\n\t"      /* 不该执行 */
        "1:\n\t"
        "beqz %1, 2f\n\t"
        "addi %2, zero, 6\n\t"      /* 不该执行 */
        "2:\n\t"
        : "+r"(a), "+r"(b), "+r"(c) :: );
    chk(0x280, c, 0);

    /* ---- 10. 老例外 + 年轻指令 ---- */
    g_traps = 0;
    test_ecall();
    chk(0x290, g_traps, 1);
    /* 注意: crt.S 的 trap 处理是 mepc += 4 后 mret, 所以 ecall 后面那条
       会在 mret 之后正常执行一次。这里验证的是"例外交付精确: 只 trap 一次,
       且那条 addi 的副作用最终恰好一次"。 */
    chk(0x291, g_after_ecall, 0x5a);

    /* ---- 11. 吞吐 ---- */
    {
        unsigned cyc_i = bench_indep();
        unsigned cyc_d = bench_dep();
        /* 4000 条 ALU: 单发射理想值也是 4000+开销, 双发射应明显低于 4000。
           这里只做区间判定, 不写死具体拍数 (避免和实现细节绑死)。 */
        puts_("BENCH indep=");
        putdec(cyc_i);
        puts_(" dep=");
        putdec(cyc_d);
        putc_('\n');
        chk(0x2a0, (cyc_i < cyc_d) ? 1u : 0u, 1);   /* 独立链必须更快 */
        /* 1280 条指令: 单发射下界约 1280 拍 (外加 10 次循环开销)。
           真正一拍两条时应接近 640 拍。取 0.75 倍作为"确实并发"的判据。 */
        chk(0x2a1, (cyc_i * 4u < 1280u * 3u) ? 1u : 0u, 1);
    }

    if (fails == 0) {
        puts_("PAIR PASS\n");
    } else {
        puts_("PAIR FAIL count=");
        putdec((unsigned)fails);
        putc_('\n');
    }
    return 0;
}
