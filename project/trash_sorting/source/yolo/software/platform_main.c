/* Static-image bring-up firmware. Camera ownership is a separate integration.
 * Requests: <"YAI1", cmd:u8, reserved:u8, length:u16, address:u32, crc:u32>
 * CRC32 covers the first 12 header bytes then payload. Stop-and-wait replies.
 */
#include "yolo_decode.h"
#include <math.h>
#include <stdint.h>

#define OSD_WIDTH 1280u
#define OSD_HEIGHT 720u
#ifndef POLL_LIMIT
#define POLL_LIMIT 100000000u
#endif

/* YOLO boxes use continuous, exclusive right/bottom edges. The frontend's
 * comparisons are inclusive integer pixel coordinates, so cover exactly the
 * source pixels intersected by the half-open box: floor(left/top), ceil(right/
 * bottom)-1, clipped to the native 1280x720 raster. */
int yolo_box_to_osd(const yolo_box_t *box,uint32_t *xy1,uint32_t *xy2)
{
    float x1,y1,x2,y2;
    uint32_t ix1,iy1,ix2,iy2;
    if(!box || !xy1 || !xy2 ||
       !isfinite(box->x1) || !isfinite(box->y1) ||
       !isfinite(box->x2) || !isfinite(box->y2) ||
       !(box->x2>box->x1 && box->y2>box->y1)) return 0;
    x1=box->x1<0.0f?0.0f:box->x1>(float)OSD_WIDTH?(float)OSD_WIDTH:box->x1;
    y1=box->y1<0.0f?0.0f:box->y1>(float)OSD_HEIGHT?(float)OSD_HEIGHT:box->y1;
    x2=box->x2<0.0f?0.0f:box->x2>(float)OSD_WIDTH?(float)OSD_WIDTH:box->x2;
    y2=box->y2<0.0f?0.0f:box->y2>(float)OSD_HEIGHT?(float)OSD_HEIGHT:box->y2;
    if(!(x2>x1 && y2>y1)) return 0;
    ix1=(uint32_t)x1;iy1=(uint32_t)y1;
    ix2=(uint32_t)x2;iy2=(uint32_t)y2;
    if((float)ix2<x2) ix2++;
    if((float)iy2<y2) iy2++;
    ix2--;iy2--;
    *xy1=(iy1<<16)|ix1;
    *xy2=(iy2<<16)|ix2;
    return 1;
}

/* Every successful inference must be committed, including an empty result.
 * The frontend holds the last box and starts its miss timeout only after an
 * explicit empty commit. Inference errors must not call display_results. */
int yolo_osd_should_commit(const yolo_box_t *results,uint32_t count)
{
    return count==0 || results!=0;
}

#if !defined(BBOX_OSD_TEST) || defined(BBOX_OSD_MMIO_TEST)
static yolo_box_t boxes[YOLO_MAX_RESULTS];

static int display_results(uint32_t count)
{
    uint32_t left,i;
    for(left=0;left<POLL_LIMIT && (acc_rd(0x98)&1);left++) {}
    if(left==POLL_LIMIT) return YOLO_TIMEOUT;
    if(!yolo_osd_should_commit(boxes,count)) return 0;
    for(i=0;i<8;i++) {
        acc_wr(0x84,i);
        uint32_t xy1,xy2;
        if(i<count && yolo_box_to_osd(&boxes[i],&xy1,&xy2)) {
            acc_wr(0x88,xy1);acc_wr(0x8c,xy2);
            acc_wr(0x90,0x80000000u|boxes[i].category);
        } else acc_wr(0x90,0);
    }
    /* An empty staging set signals a successful miss to the RTL hold timer. */
    acc_wr(0x94,1);acc_fence();
    return 0;
}

#endif

#ifndef BBOX_OSD_TEST
#include "yolo_runtime.h"
#include "deployment_model.h"
#include <string.h>

#ifndef CPU_HZ
#define CPU_HZ 27000000u
#endif
#ifdef VEXII_PLATFORM
#define UART ((volatile uint32_t *)(uintptr_t)0x10001000u)
#else
#define UART ((volatile uint32_t *)(uintptr_t)0x30000000u)
#endif
extern int yolo_forward(uint32_t,uint64_t *,int *);
/* Capture finishes before decoding starts; reuse storage on the 64 KiB CPU. */
static union {
    yolo_decode_workspace_t decode;
    uint8_t input_row[320u * 8u];
} frame_workspace;
static uint8_t model_verified;
static uint32_t input_loaded;
/* cmd8 returns CPU cycles for the last request, followed by one word per op.
 * cmd9 selects baseline (0) or individual optimizations (bits 0..5). */
static uint32_t profile[8+YOLO_N_OPS];
static yolo_decode_config_t decode_cfg={
    .anchors={{{10,13},{16,30},{33,23}},{{30,61},{62,45},{59,119}},
              {{116,90},{156,198},{373,326}}},
    .strides={8,16,32},.confidence=.25f,.iou=.45f,.ratio=1,
    .original_w=320,.original_h=320
};

static uint32_t crc_update(uint32_t crc,const unsigned char *p,uint32_t n)
{
    uint32_t j;
    while(n--) {
        crc^=*p++;
        for(j=0;j<8;j++) crc=(crc>>1)^(0xedb88320u & (0u-(crc&1u)));
    }
    return crc;
}
static unsigned char receive(void)
{
#ifdef VEXII_PLATFORM
    /* The data register read is also the FIFO pop, so it must never happen
     * while the receive queue is empty: that would return the uninitialised
     * FIFO RAM (X in simulation, garbage on silicon, and it poisons the PC)
     * and would silently discard one byte.  Poll the occupancy field of the
     * status register (bits 29:24) first, then pop exactly one byte. */
    while(!(UART[1] & 0x3f000000u)) {}
    return (unsigned char)UART[0];
#else
    unsigned char c;
    while(!(UART[1]&2u)) {}
    c=(unsigned char)UART[4];
    UART[1]=0;
    return c;
#endif
}
static void send(unsigned char c)
{
#ifdef VEXII_PLATFORM
    while(!(UART[1]&0x003f0000u)) {}
    UART[0]=c;
#else
    while(UART[1]&1u) {}
    UART[3]=c;
#endif
}
static void reply(uint8_t status,const void *payload,uint16_t n)
{
    unsigned char header[8]={'Y','A','R','1',status,(unsigned char)n,(unsigned char)(n>>8),0};
    const unsigned char *p=payload;
    uint32_t i,crc=crc_update(~0u,header,8);
    crc=~crc_update(crc,p,n);
    for(i=0;i<8;i++) send(header[i]);
    for(i=0;i<n;i++) send(p[i]);
    for(i=0;i<4;i++) send((unsigned char)(crc>>(i*8)));
}

static int capture_input(void)
{
    uint32_t left,y,x;
    acc_wr(0x74,1);
    acc_fence();
    for(left=0;left<POLL_LIMIT;left++) {
        uint32_t s=acc_rd(0x80);
        if(s&4) return YOLO_IO;
        if((s&3)==2) break;
    }
    if(left==POLL_LIMIT) return YOLO_TIMEOUT;
    for(y=0;y<320;y++) {
        for(x=0;x<320;x++) {
        uint64_t word=57u | (57ull<<8) | (57ull<<16); // letterbox RGB 114
        if(y>=70 && y<250) {
            uint32_t pixel,r,g,b;
            acc_wr(0x78,(y-70)*320+x);
            acc_fence();
            pixel=acc_rd(0x7c);
            r=(pixel>>11)&31;g=(pixel>>5)&63;b=pixel&31;
            r=(r<<3)|(r>>2);g=(g<<2)|(g>>4);b=(b<<3)|(b>>2);
            r=(r*127+127)/255;g=(g*127+127)/255;b=(b*127+127)/255;
            word=r | ((uint64_t)g<<8) | ((uint64_t)b<<16);
        }
        memcpy(frame_workspace.input_row+x*8u,&word,8);
        }
        {
            int rc=acc_memory_write_bulk(yolo_tensors[0].address+y*320u*8u,
                                          frame_workspace.input_row,
                                          sizeof frame_workspace.input_row,
                                          POLL_LIMIT);
            if(rc) return rc;
        }
    }
    decode_cfg.ratio=.25f;decode_cfg.pad_x=0;decode_cfg.pad_y=70;
    decode_cfg.original_w=1280;decode_cfg.original_h=720;
    return 0;
}


static int infer_reply(const yolo_io_t *io,uint32_t limit,int camera)
{
    uint64_t cycles=0;
    int bad=-1,status=0;
    yolo_tensor_t heads[3];
    uint32_t i,count=0,started;
    if(!model_verified || (!camera && input_loaded!=320u*320u*8u)) {
        reply(YOLO_INVALID,0,0);return YOLO_INVALID;
    }
    memset(profile,0,sizeof profile);
    profile[0]=1;profile[1]=CPU_HZ;profile[2]=yolo_runtime_options;profile[3]=YOLO_N_OPS;
    started=yolo_clock();
    if(camera) status=capture_input();
    profile[4]=yolo_clock()-started;
    started=yolo_clock();
    /* An anchor's final confidence cannot exceed its objectness. Keep a
     * margin for Q16 rounding; the decoder still applies its own threshold. */
    yolo_head_logit_floor=decode_cfg.confidence<1 ?
        logf(decode_cfg.confidence/(1-decode_cfg.confidence))-.001f : 16.0f;
    if(yolo_head_logit_floor>16) yolo_head_logit_floor=16;
    if(!status) status=yolo_forward(limit,&cycles,&bad);
    profile[5]=yolo_clock()-started;
    for(i=0;i<YOLO_N_OPS;i++) profile[8+i]=yolo_op_cycles[i];
    for(i=0;i<3;i++) heads[i]=yolo_tensors[yolo_outputs[i]];
    started=yolo_clock();
    if(!status) status=yolo_decode(io,heads,&decode_cfg,&frame_workspace.decode,boxes,&count);
    profile[6]=yolo_clock()-started;
    started=yolo_clock();
    /* Only successful inference results may start the frontend miss timer. */
    if(!status && camera) status=display_results(count);
    profile[7]=yolo_clock()-started;
    if(status) {
        uint32_t error[2]={(uint32_t)status,(uint32_t)bad};
        reply((uint8_t)status,error,sizeof error);
    } else {
        unsigned char result[4+sizeof boxes];
        memcpy(result,&count,4);memcpy(result+4,boxes,count*sizeof(*boxes));
        reply(0,result,(uint16_t)(4+count*sizeof(*boxes)));
    }
    return status;
}
int main(void)
{
    unsigned char header[16],payload[256];
    uint32_t limit=POLL_LIMIT;
    yolo_io_t io={
        .context=&limit,.read64=yolo_acc_read,.write64=yolo_acc_write,
        .convolve=yolo_acc_convolve,.read_bulk=yolo_acc_read_bulk,
        .write_bulk=yolo_acc_write_bulk
    };
#ifdef VEXII_PLATFORM
    UART[2]=CPU_HZ/(115200u*8u)-1u;
    UART[3]=7;
#else
    UART[2]=(CPU_HZ+57600u)/115200u-1u;
    UART[0]=3;
#endif
#ifdef VEXII_SIM_PRELOAD
    model_verified=1;
    input_loaded=320u*320u*8u;
#endif
    for(;;) {
        uint32_t i,address,expected,crc;
        uint16_t n;
        uint8_t cmd,status=0;
        /* Sliding magic synchronization also recovers after an oversized frame. */
        uint32_t magic=0;
        do {magic=(magic<<8)|receive();} while(magic!=0x59414931u);
        memcpy(header,"YAI1",4);
        for(i=4;i<16;i++) header[i]=receive();
        cmd=header[4];n=(uint16_t)(header[6]|header[7]<<8);
        memcpy(&address,header+8,4);memcpy(&expected,header+12,4);
        if(n>sizeof payload) {reply(YOLO_INVALID,0,0);continue;}
        for(i=0;i<n;i++) payload[i]=receive();
        crc=~crc_update(crc_update(~0u,header,12),payload,n);
        if(crc!=expected) {reply(YOLO_INVALID,0,0);continue;}
        if(cmd==1 || cmd==2) {
            uint16_t length=cmd==2?8:n;
            if((address&7) || (length&7) || !length ||
               address<YOLO_BLOB_BASE || address>0x03000000u-length) {
                reply(YOLO_INVALID,0,0);continue;
            }
            if(cmd==2) {
                uint64_t word=0;
                if(n) {reply(YOLO_INVALID,0,0);continue;}
                status=(uint8_t)acc_memory_read64(address,&word,limit);
                reply(status,&word,8);continue;
            }
            if(address<YOLO_BLOB_BASE+YOLO_BLOB_LENGTH) model_verified=0;
            status=(uint8_t)acc_memory_write_bulk(address,payload,n,limit);
            if(address>=yolo_tensors[0].address &&
               address<yolo_tensors[0].address+320u*320u*8u) {
                if(!status && address==yolo_tensors[0].address+input_loaded)
                    input_loaded+=n;
                else if(!status && address==yolo_tensors[0].address) input_loaded=n;
                else input_loaded=0;
                if(input_loaded>320u*320u*8u) input_loaded=0;
            }
        } else if((cmd==3 || cmd==6) && n==0) {
            infer_reply(&io,limit,cmd==6);
            continue;
        } else if(cmd==7 && n==0 && model_verified) {
            reply(0,0,0);
            /* Autonomous demo; resetting the board leaves this mode. */
            while(!infer_reply(&io,limit,1)) {}
            continue;
        } else if(cmd==8 && n==0) {
            reply(0,profile,sizeof profile);continue;
        } else if(cmd==9 && n==0 && address<=63u) {
            yolo_runtime_options=address;
            reply(0,&yolo_runtime_options,sizeof yolo_runtime_options);continue;
        } else if(cmd==4 && n==16) {
            float values[3];
            uint16_t dimensions[2];
            memcpy(values,payload,12);memcpy(dimensions,payload+12,4);
            if(!(values[0]>0) || !dimensions[0] || !dimensions[1]) status=YOLO_INVALID;
            else {
                decode_cfg.ratio=values[0];decode_cfg.pad_x=values[1];decode_cfg.pad_y=values[2];
                decode_cfg.original_w=dimensions[0];decode_cfg.original_h=dimensions[1];
            }
        } else if(cmd==5 && n==0) {
            uint32_t crc_model=~0u;
            status=(uint8_t)acc_memory_crc_bulk(YOLO_BLOB_BASE,
                                                YOLO_BLOB_LENGTH,
                                                limit,&crc_model);
            model_verified=(uint8_t)(!status && ~crc_model==YOLO_BLOB_CRC32);
            if(!model_verified) status=YOLO_INVALID;
        } else status=YOLO_INVALID;
        reply(status,0,0);
    }
}
#endif
