/* Execute the actual firmware preprocessing against an immutable fake camera
 * and byte-addressed DDR. No alternative copy of the implementation is used. */
#include "yolo_decode.h"
#include "deployment_model.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint16_t pixels[57600];
static unsigned char input_ddr[320*320*8], reference[320*320*8];
static uint32_t pointer, address_writes, legacy_reads, stream_reads, ticks;
static int capture_error, bulk_error;
static uint32_t mock_read(uint32_t offset)
{
    if(offset==0x80) return capture_error ? 4 : 2;
    if(offset==0x7c) {
        legacy_reads++;
        return pointer<57600 ? pixels[pointer] : 0;
    }
    if(offset==0xbc) {
        uint32_t pixel,r,g,b;
        stream_reads++;
        if(pointer>=57600) return 0;
        pixel=pixels[pointer++];
        r=(pixel>>11)&31;g=(pixel>>5)&63;b=pixel&31;
        return ((r<<2)+(r>>3)) | (((g<<1)+(g>>5))<<8) | (((b<<2)+(b>>3))<<16);
    }
    assert(0);return 0;
}
static void mock_write(uint32_t offset,uint32_t value)
{
    if(offset==0x78) { pointer=value;address_writes++; }
    else assert(offset==0x74 && value==1);
}
static int mock_write_bulk(uint32_t address,const void *data,uint32_t length,uint32_t limit)
{
    (void)limit;
    if(bulk_error) return YOLO_IO;
    assert(address>=yolo_tensors[0].address);
    address-=yolo_tensors[0].address;
    assert(address+length<=sizeof input_ddr);
    memcpy(input_ddr+address,data,length);return 0;
}
static int mock_crc(uint32_t address,uint32_t length,uint32_t limit,uint32_t *crc)
{
    (void)limit;
    assert(address==yolo_tensors[0].address && length==sizeof input_ddr);
    *crc=acc_crc_update(*crc,input_ddr,length);return 0;
}
#define acc_rd mock_read
#define acc_wr mock_write
#define acc_fence() ((void)0)
#define acc_memory_write_bulk mock_write_bulk
#define acc_memory_crc_bulk mock_crc
#define yolo_clock() (++ticks)
#define main uncalled_firmware_main
#include "../source/yolo/software/platform_main.c"
#undef main

static void expected_input(void)
{
    unsigned int y,x;
    memset(reference,0,sizeof reference);
    for(y=0;y<320;y++) for(x=0;x<320;x++) {
        unsigned char *destination=reference+(y*320+x)*8;
        if(y<70 || y>=250) destination[0]=destination[1]=destination[2]=57;
        else {
            unsigned int p=pixels[(y-70)*320+x],r=(p>>11)&31,g=(p>>5)&63,b=p&31;
            r=(r<<3)|(r>>2);g=(g<<2)|(g>>4);b=(b<<3)|(b>>2);
            destination[0]=(r*127+127)/255;
            destination[1]=(g*127+127)/255;
            destination[2]=(b*127+127)/255;
        }
    }
}
int main(void)
{
    unsigned int frame,i,mode;
    uint32_t result[4];
    /* Together the two frames cover all 65536 RGB565 values. */
    for(frame=0;frame<2;frame++) {
        for(i=0;i<57600;i++) pixels[i]=(uint16_t)(i+frame*57600);
        expected_input();
        for(mode=0;mode<2;mode++) {
            camera_fast=mode;address_writes=legacy_reads=stream_reads=0;
            memset(input_ddr,0xcc,sizeof input_ddr);
            assert(!capture_input());
            assert(!memcmp(input_ddr,reference,sizeof reference));
            assert(legacy_reads==(mode?0:57600));
            assert(stream_reads==(mode?57600:0));
            assert(address_writes==(mode?1:57601));
            assert(decode_cfg.ratio==.25f && decode_cfg.pad_y==70);
        }
        assert(!compare_camera_inputs(result));
        assert(result[0]==result[1] && result[2] && result[3]);
        assert(camera_fast==1 && input_loaded==sizeof input_ddr);
    }
    capture_error=1;
    assert(capture_input()==YOLO_IO);
    capture_error=0;bulk_error=1;
    assert(compare_camera_inputs(result)==YOLO_IO);
    assert(camera_fast==1);
    puts("CAMERA_PREPROCESS_PASS actual firmware, 65536 colors, packed input, letterbox, CRC, errors; 57600 address writes removed per frame");
    return 0;
}
