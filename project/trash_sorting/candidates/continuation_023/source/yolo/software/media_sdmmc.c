#include "media_sdmmc.h"
#include <string.h>

#define START (1u<<31)
#define ABORT (1u<<30)
#define FIFO_RESET (1u<<29)
#define BUSY 1u
#define CRC_ERROR 2u
#define FIFO_EMPTY 8u
#define R1_ERRORS 0xfdffe008u
#define MAX_POLLS 200000u
static int wr(media_sdmmc_t*c,uint32_t a,uint32_t v){
    return c->io.write32(c->io.context,a,v)?SDMMC_IO:0;
}
static int rd(media_sdmmc_t*c,uint32_t a,uint32_t*v){
    return c->io.read32(c->io.context,a,v)?SDMMC_IO:0;
}
static uint32_t now(media_sdmmc_t*c){return c->io.milliseconds(c->io.context);}
static int guard(media_sdmmc_t*c,uint32_t started,uint32_t ms,unsigned polls){
    if(c->io.cancelled && c->io.cancelled(c->io.context))return SDMMC_CANCELLED;
    /* Poll bound also terminates safely if a platform clock stops. */
    return (uint32_t)(now(c)-started)>=ms || polls>=MAX_POLLS?SDMMC_TIMEOUT:0;
}
void media_sdmmc_abort(media_sdmmc_t*c){
    (void)wr(c,0,ABORT|FIFO_RESET|(c->wide?8u:0));
}
static int delay(media_sdmmc_t*c,uint32_t ms){
    uint32_t t=now(c);unsigned n=0;
    while((uint32_t)(now(c)-t)<ms){
        if(c->io.cancelled && c->io.cancelled(c->io.context))return SDMMC_CANCELLED;
        if(++n>=MAX_POLLS)return SDMMC_TIMEOUT;
    }return 0;
}
static uint32_t bits(const uint32_t*r,unsigned lo,unsigned width){
    uint32_t v=0;for(unsigned i=0;i<width;i++)v|=((r[(lo+i)/32]>>((lo+i)%32))&1u)<<i;
    return v;
}
static int response_crc(const uint32_t*r,int long_response){
    uint8_t crc=0;
    for(unsigned b=long_response?128u:48u;b-->8;){
        unsigned x=(crc>>6)^bits(r,b,1);crc=(crc<<1)&127u;if(x&1)crc^=9;
    }
    return (r[0]&1u) && ((r[0]>>1)&127u)==crc;
}
/* flags: 0=no response, 1=R48, 2=R136, 5=R48+single block read.
 * There is deliberately no WRITE or DMA command path. */
static int command(media_sdmmc_t*c,unsigned cmd,uint32_t arg,unsigned flags,uint32_t r[5]){
    uint32_t t=now(c),status=0;int e;
    if((e=guard(c,t,500,0)))return e;
    if((e=wr(c,0,FIFO_RESET|(c->wide?8u:0))) ||
       (e=wr(c,0x0c,(cmd<<24)|(arg>>8))) ||
       (e=wr(c,0x10,(arg&255u)<<8)) ||
       (e=wr(c,0,START|flags|(c->wide?8u:0))))return e;
    /* A register transaction completes after the controller has sampled START. */
    for(unsigned polls=0;;polls++){
        if((e=rd(c,8,&status)))return e;
        if(!(status&BUSY))break;
        if((e=guard(c,t,500,polls))){media_sdmmc_abort(c);return e;}
    }
    if((flags&4) && (status&CRC_ERROR))return SDMMC_CRC;
    if(!(flags&3))return 0;
    for(unsigned i=0;i<5;i++)if((e=rd(c,0x14+4*i,r+i)))return e;
    /* R3 (ACMD41) has reserved CRC bits. All other responses must pass CRC7. */
    if(cmd!=41 && !response_crc(r,(flags&2)!=0))return SDMMC_CRC;
    if(flags&2){if(bits(r,128,8)!=0x3f)return SDMMC_RESPONSE;}
    else if(bits(r,40,8)!=(cmd==41?63u:cmd))return SDMMC_RESPONSE;
    return 0;
}
static uint32_t argument(const uint32_t*r){return r[0]>>8|r[1]<<24;}
static int r1(media_sdmmc_t*c,unsigned cmd,uint32_t arg,unsigned flags){
    uint32_t r[5];int e=command(c,cmd,arg,flags,r);
    return e?e:(argument(r)&R1_ERRORS)?SDMMC_RESPONSE:0;
}
static int app(media_sdmmc_t*c,unsigned cmd,uint32_t arg,uint32_t r[5]){
    int e=r1(c,55,(uint32_t)c->rca<<16,1);return e?e:command(c,cmd,arg,1,r);
}
void media_sdmmc_setup(media_sdmmc_t*c,const media_sdmmc_io_t*io,uint32_t hz){
    memset(c,0,sizeof *c);c->io=*io;c->clock_hz=hz;
}
int media_sdmmc_init(media_sdmmc_t*c){
    uint32_t r[5],t,status,divider;int e;
    c->ready=0;c->wide=0;c->rca=0;c->sectors=0;
    if(!c->io.read32 || !c->io.write32 || !c->io.milliseconds || !c->clock_hz)return SDMMC_IO;
    divider=(c->clock_hz+799999u)/800000u;
    if(!divider || divider>256)return SDMMC_UNSUPPORTED;
    if((e=wr(c,0,ABORT|FIFO_RESET)) || (e=wr(c,4,divider-1)) || (e=delay(c,2)))return e;
    if((e=command(c,0,0,0,r)) || (e=command(c,8,0x1aa,1,r)))return e;
    if(argument(r)!=0x1aa)return SDMMC_UNSUPPORTED;
    t=now(c);
    for(unsigned n=0;;n++){
        if((e=app(c,41,0x40ff8000,r)))return e;
        status=argument(r);
        if(status&0x80000000u)break;
        if((e=guard(c,t,1200,n)) || (e=delay(c,2)))return e;
    }
    if(!(status&0x00ff8000u))return SDMMC_UNSUPPORTED;
    c->high_capacity=(status>>30)&1;
    if((e=command(c,2,0,2,r)) || (e=command(c,3,0,1,r)))return e;
    status=argument(r);c->rca=(uint16_t)(status>>16);
    if(!c->rca || (status&0xe000))return SDMMC_RESPONSE;
    if((e=command(c,9,(uint32_t)c->rca<<16,2,r)))return e;
    uint64_t sectors;
    if(bits(r,126,2)==1)sectors=((uint64_t)bits(r,48,22)+1u)*1024u;
    else if(bits(r,126,2)==0){
        unsigned shift=bits(r,47,3)+bits(r,80,4);
        if(shift<7 || shift>38)return SDMMC_UNSUPPORTED;
        sectors=((uint64_t)bits(r,62,12)+1u)<<(shift-7);
    }else return SDMMC_UNSUPPORTED;
    if(!sectors || sectors>UINT32_MAX)return SDMMC_UNSUPPORTED;
    c->sectors=(uint32_t)sectors;
    if((e=r1(c,7,(uint32_t)c->rca<<16,1)))return e;
    t=now(c);
    for(unsigned n=0;;n++){
        if((e=rd(c,8,&status)))return e;
        if(status&0x10)break; /* R1b DAT0 busy released. */
        if((e=guard(c,t,500,n)))return e;
    }
    if(!c->high_capacity && (e=r1(c,16,512,1)))return e;
    if((e=app(c,6,2,r)))return e;
    if(argument(r)&R1_ERRORS)return SDMMC_RESPONSE;
    c->wide=1;
    /* Standard-speed SD cards allow 25 MHz. Round down via a divider. */
    divider=(c->clock_hz+49999999u)/50000000u;
    if((e=wr(c,4,divider-1)))return e;
    c->ready=1;return 0;
}
int media_sdmmc_read_begin(media_sdmmc_t*c,uint32_t lba){
    if(!c->ready || lba>=c->sectors || (!c->high_capacity && lba>UINT32_MAX/512))return SDMMC_RANGE;
    return r1(c,17,c->high_capacity?lba:lba*512,5);
}
int media_sdmmc_read(media_sdmmc_t*c,uint32_t lba,uint8_t data[512]){
    int e;uint32_t word,status;
    if(!data)return SDMMC_RANGE;
    if((e=media_sdmmc_read_begin(c,lba)))return e;
    for(unsigned i=0;i<128;i++){
        if((e=rd(c,8,&status)))return e;
        if(status&(CRC_ERROR|FIFO_EMPTY))return status&CRC_ERROR?SDMMC_CRC:SDMMC_IO;
        if((e=rd(c,0x2c,&word)))return e;
        for(unsigned b=0;b<4;b++)data[4*i+b]=(uint8_t)(word>>(8*b));
    }
    if((e=rd(c,8,&status)))return e;
    return status&CRC_ERROR?SDMMC_CRC:!(status&FIFO_EMPTY)?SDMMC_IO:0;
}
int media_sdmmc_sector_callback(void*c,uint32_t lba,uint8_t data[512]){
    return media_sdmmc_read((media_sdmmc_t*)c,lba,data);
}
