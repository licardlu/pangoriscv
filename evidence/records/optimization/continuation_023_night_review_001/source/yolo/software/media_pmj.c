#include "media_pmj.h"
#include <string.h>
static uint32_t u32(const uint8_t*b){return (uint32_t)b[0]|(uint32_t)b[1]<<8|(uint32_t)b[2]<<16|(uint32_t)b[3]<<24;}
static uint16_t u16(const uint8_t*b){return (uint16_t)(b[0]|b[1]<<8);}
uint32_t media_crc32_update(uint32_t c,const uint8_t*b,uint32_t n){
    while(n--){c^=*b++;for(unsigned i=0;i<8;i++)c=(c>>1)^((0u-(c&1))&0xedb88320u);}return c;
}
static int read_at(media_pmj_t*m,uint32_t o,void*d,uint32_t n){
    if(o>m->file.size || n>m->file.size-o)return PMJ_RANGE;
    return m->file.read(m->file.context,o,d,n)?PMJ_IO:0;
}
int media_pmj_open(media_pmj_t*m,const media_pmj_reader_t*f){
    uint8_t buffer[512];uint32_t expected=0,crc=~0u;int e;
    memset(m,0,sizeof *m);m->file=*f;
    if(!f->read || f->size<4096)return PMJ_FORMAT;
    for(uint32_t o=0;o<4096;o+=sizeof buffer){
        if((e=read_at(m,o,buffer,sizeof buffer)))return e;
        if(!o){
            if(memcmp(buffer,"PANGMJ01",8) || u16(buffer+8)!=1 || u16(buffer+10)!=4096 || u32(buffer+32)!=1)return PMJ_FORMAT;
            m->width=u16(buffer+12);m->height=u16(buffer+14);m->fps=u32(buffer+16);
            m->count=u32(buffer+20);m->index_offset=u32(buffer+24);m->payload_offset=u32(buffer+28);
            expected=u32(buffer+36);memset(buffer+36,0,4);
        }
        crc=media_crc32_update(crc,buffer,sizeof buffer);
    }
    if(~crc!=expected)return PMJ_CRC;
    if(m->width<16 || m->width>1280 || m->width%16 || m->height<16 || m->height>720 || m->height%16 ||
       m->fps<1 || m->fps>60 || !m->count || m->count>65535 || m->index_offset!=4096 ||
       m->payload_offset<m->index_offset+m->count*24 || m->payload_offset%512 || m->payload_offset>=f->size)return PMJ_FORMAT;
    return 0;
}
static int index_at(media_pmj_t*m,uint32_t n,media_pmj_frame_t*f){
    uint8_t b[24];int e;
    if(n>=m->count)return PMJ_RANGE;
    if((e=read_at(m,m->index_offset+n*24,b,sizeof b)))return e;
    if(u32(b+4) || u32(b+20))return PMJ_RANGE;
    f->offset=u32(b);f->length=u32(b+8);f->crc32=u32(b+12);f->pts_ms=u32(b+16);
    if(!f->length || f->length>4u*1024*1024 || f->offset<m->payload_offset ||
       f->offset>m->file.size || f->length>m->file.size-f->offset || f->pts_ms!=n*1000/m->fps)return PMJ_RANGE;
    return 0;
}
int media_pmj_frame(media_pmj_t*m,uint32_t n,media_pmj_frame_t*f){
    media_pmj_frame_t previous;int e;
    if(!m->count || (e=index_at(m,n,f)))return !m->count?PMJ_FORMAT:e;
    if(!n){if(f->offset!=m->payload_offset)return PMJ_FORMAT;}
    else{
        if((e=index_at(m,n-1,&previous)))return e;
        if(f->offset!=previous.offset+previous.length)return PMJ_FORMAT;
    }
    if(n==m->count-1 && f->offset+f->length!=m->file.size)return PMJ_FORMAT;
    return 0;
}
int media_pmj_check_frame(media_pmj_t*m,const media_pmj_frame_t*f){
    uint8_t buffer[512];uint32_t crc=~0u,left=f->length,o=f->offset;int e;
    while(left){uint32_t n=left>sizeof buffer?sizeof buffer:left;
        if((e=read_at(m,o,buffer,n)))return e;
        crc=media_crc32_update(crc,buffer,n);o+=n;left-=n;
    }return ~crc==f->crc32?0:PMJ_CRC;
}
