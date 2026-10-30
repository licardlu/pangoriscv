#include <stdint.h>
volatile unsigned g_cause,g_epc,g_tval,g_traps;
void trap_report(unsigned a,unsigned b,unsigned c){g_cause=a;g_epc=b;g_tval=c;g_traps=g_traps+1;}
#define MMIO(a) (*(volatile unsigned *)(a))
void uart_send_char(char c){ if(c=='\n') uart_send_char('\r'); while((MMIO(0x10001004)&0x00ff0000)==0){} MMIO(0x10001000)=(unsigned char)c; }
int ee_printf(const char *fmt, ...);
int main(void){
    ee_printf("S1=%s\n", "HELLO");
    ee_printf("C1=%c\n", 'Z');
    ee_printf("N1=%u\n", 7u);
    ee_printf("N2=%u\n", 42u);
    ee_printf("N3=%u\n", 120461538u);
    while(1){}
    return 0;
}
