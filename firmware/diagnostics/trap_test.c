/* Independent machine-mode validation firmware; does not link CoreMark. */
typedef unsigned u32;
typedef unsigned long long u64;
#define MMIO(a) (*(volatile u32 *)(a))
#define CLINT 0x10010000u
#define MTIMECMP (CLINT + 0x4000u)
#define MTIME (CLINT + 0xbff8u)
volatile u32 timer_hits;
static volatile u32 stage, unexpected, last_cause, last_pc, last_value, exceptions;
extern char illegal_pc[], ecall_pc[], timer_begin[], timer_end[];
extern int probe_illegal(void), probe_ecall(void), probe_timer(void);

static void putc_uart(char c) {
    if(c=='\n') putc_uart('\r');
    while(!(MMIO(0x10001004u) & 0x00ff0000u)) {}
    MMIO(0x10001000u)=(unsigned char)c;
}
static void puts_uart(const char *s) { while(*s) putc_uart(*s++); }
static void hex(u32 n) {
    static const char digits[]="0123456789abcdef";
    for(int shift=28;shift>=0;shift-=4) putc_uart(digits[(n>>shift)&15]);
}
static void report(void) {
    puts_uart("MCAUSE="); hex(last_cause);
    puts_uart(" MEPC="); hex(last_pc);
    puts_uart(" MTVAL="); hex(last_value); putc_uart('\n');
}
static void fail(void) {
    puts_uart("DIAG_FAIL\n");
    MMIO(0x10003000u)=0xee;
    for(;;) {}
}
static u64 time_read(void) {
    /* TilelinkClint latches high bits when low is read (see RTL). */
    u32 low=MMIO(MTIME), high=MMIO(MTIME+4);
    return ((u64)high<<32)|low;
}
static void compare_write(u64 n) {
    /* RV32 safe update: avoid a transient compare in the past. */
    MMIO(MTIMECMP+4)=0xffffffffu;
    MMIO(MTIMECMP)=(u32)n;
    MMIO(MTIMECMP+4)=(u32)(n>>32);
    __asm__ volatile("fence iorw,iorw" ::: "memory");
}
u32 diag_trap(u32 cause,u32 pc,u32 value) {
    last_cause=cause; last_pc=pc; last_value=value;
    if(stage==1 && cause==2 && pc==(u32)illegal_pc) {
        ++exceptions; return pc+4;
    }
    if(stage==2 && cause==11 && pc==(u32)ecall_pc) {
        ++exceptions; return pc+4;
    }
    if(stage==3 && cause==0x80000007u &&
       pc>=(u32)timer_begin && pc<(u32)timer_end) {
        __asm__ volatile("csrc mie,%0" :: "r"(128u) : "memory");
        compare_write(~(u64)0);
        ++timer_hits;
        return pc; /* Interrupt returns to the unexecuted instruction. */
    }
    unexpected=1;
    __asm__ volatile("csrw mie,zero" ::: "memory");
    return pc+4; /* Main detects the unexpected event and fails. */
}
int main(void) {
    MMIO(0x10001008u)=120461538u/(115200u*8)-1;
    MMIO(0x1000100cu)=7;
    compare_write(~(u64)0);
    puts_uart("TRAP_DIAG_BOOT\n");
    stage=1;
    if(probe_illegal() || exceptions!=1 || unexpected) fail();
    report(); puts_uart("ILLEGAL_PASS\n");
    stage=2;
    if(probe_ecall() || exceptions!=2 || unexpected) fail();
    report(); puts_uart("ECALL_PASS\n");
    stage=3;
    u64 target=time_read()+5000u;
    compare_write(target);
    /* Pending MTIP must not trap while MIE/MTIE are disabled. */
    while(time_read()<=target+32u) {}
    if(timer_hits || unexpected) fail();
    if(probe_timer() || timer_hits!=1 || unexpected) fail();
    __asm__ volatile("csrci mstatus,8" ::: "memory");
    report(); puts_uart("TIMER_PASS\nDIAG_DONE\n");
    MMIO(0x10003000u)=0xa5;
    return 0;
}

