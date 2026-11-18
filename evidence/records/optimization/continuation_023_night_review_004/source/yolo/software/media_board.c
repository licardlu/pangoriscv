#include "media_board.h"
#include "media_player.h"
#include <string.h>
#ifdef MEDIA_BOARD_TEST
#include "media_board_test_port.h"
#else
#include "acc_regs.h"
#endif
#ifndef CPU_HZ
#define CPU_HZ 54000000u
#endif
uint32_t media_board_page(void){return (acc_rd(0x9c)>>16)&3u;}
int media_navigation_active(void){return media_board_page()!=0;}
static int wait_idle(uint32_t*status){
    for(uint32_t n=0;n<100000u;n++){
        *status=acc_rd(0x9c);if(!(*status&0x80000000u))return 0;
    }return -1;
}
static int transfer(uint32_t address,uint32_t*value,int write){
    uint32_t status;
    if(address>0xfffu || address&3 || wait_idle(&status))return -1;
    if(write)acc_wr(0xb8,*value);
    acc_wr(0x9c,address|(write?0x80000000u:0));acc_fence();
    if(wait_idle(&status) || status&0x40000000u)return -1;
    if(!write)*value=acc_rd(0xb8);
    return 0;
}
static int read_reg(void*c,uint32_t a,uint32_t*v){(void)c;return transfer(a,v,0);}
int media_board_diagnostics(uint32_t result[7]){
    static const uint16_t addresses[7]={0x200,0x204,0x208,0x114,0x110,0x10c,0x08};
    if(!result)return -1;
    for(unsigned i=0;i<7;i++)if(transfer(addresses[i],result+i,0))return -1;
    return 0;
}
int media_board_read_frame(uint32_t address,uint8_t data[256],uint32_t limit){
    /* CPU addresses are bytes; native media banks use 32-bit word addresses.
     * Read only complete chunks within actual pixel storage, never bank gaps.
     * A live snapshot requires pausing the producer, not the HDMI scanout. */
    if(!data || (address&7u) ||
       !((address>=0x0a000000u && address<=0x0a383f00u) ||
         (address>=0x0a400000u && address<=0x0a783f00u)) ||
       (media_board_page()==2 && !media_player_paused()))return -1;
    for(unsigned i=0;i<256;i+=8){
        uint64_t word;int rc=acc_memory_read64(address+i,&word,limit);
        if(rc)return rc;
        memcpy(data+i,&word,8);
    }
    return 0;
}
static int write_reg(void*c,uint32_t a,uint32_t v){(void)c;return transfer(a,&v,1);}
static uint32_t milliseconds(void*c){
    (void)c;
#ifdef MEDIA_BOARD_TEST
    uint64_t cycles=media_test_cycles();
#else
    uint32_t hi,lo,again;
    do{
        __asm__ volatile("csrr %0,mcycleh":"=r"(hi));
        __asm__ volatile("csrr %0,mcycle":"=r"(lo));
        __asm__ volatile("csrr %0,mcycleh":"=r"(again));
    }while(hi!=again);
    uint64_t cycles=((uint64_t)hi<<32)|lo;
#endif
    return (uint32_t)(cycles/(CPU_HZ/1000u));
}
static uint32_t page(void*c){(void)c;return media_board_page();}
void media_board_init(void){
    const media_player_io_t io={read_reg,write_reg,milliseconds,page,0};
    media_player_setup(&io,CPU_HZ,1280,720);
}
