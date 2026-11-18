#include "stereo_depth.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static uint8_t images[2][180][320];
static stereo_workspace_t workspace;
static int read_pixel(void*ctx,unsigned side,int x,int y,uint8_t*out){
    (void)ctx;
    if(side>1||x<0||x>=320||y<0||y>=180)return -1;
    *out=images[side][y][x];return 0;
}
static void plane(int disparity){
    uint32_t rng=1289;
    memset(images,0,sizeof images);
    for(int y=0;y<180;y++)for(int x=0;x<320;x++){
        rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;
        images[0][y][x]=(uint8_t)rng;
    }
    for(int y=0;y<180;y++)for(int x=0;x<320-disparity;x++)
        images[1][y][x]=images[0][y][x+disparity];
}
static stereo_calibration_t config(void){
    stereo_calibration_t c={.width=320,.height=180,.max_disparity=64,
        .max_skew_ms=5,.limit_mm=200,.error_mm=5,.verified=7,.focal_baseline_q8=6000*256};
    for(int i=0;i<2;i++){
        c.camera[i].fx=200;c.camera[i].fy=200;
        c.camera[i].cx=160;c.camera[i].cy=90;
        c.camera[i].inverse_rectified[0]=.005f;
        c.camera[i].inverse_rectified[2]=-.8f;
        c.camera[i].inverse_rectified[4]=.005f;
        c.camera[i].inverse_rectified[5]=-.45f;
        c.camera[i].inverse_rectified[8]=1;
        c.camera[i].forward_rectified[0]=200;
        c.camera[i].forward_rectified[2]=160;
        c.camera[i].forward_rectified[4]=200;
        c.camera[i].forward_rectified[5]=90;
        c.camera[i].forward_rectified[8]=1;
    }
    return c;
}
int main(void){
    stereo_calibration_t c=config();
    stereo_measurement_t r;
    int roi[4];
    assert(!stereo_rectified_roi(&c,100,30,120,120,roi));
    assert(roi[0]==100&&roi[1]==30&&roi[2]==119&&roi[3]==119);
    plane(40);
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_NEAR&&r.valid_points==9&&r.median_mm==150);
    plane(20);
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_FAR&&r.median_mm==300);
    plane(30); // True 200mm lies on the uncertain boundary, never confirmed near.
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_UNKNOWN&&r.median_mm==200);
    c.verified=STEREO_CALIBRATED;
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_UNKNOWN&&r.valid_points==0);
    c=config();
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,6,&workspace);
    assert(r.status==STEREO_UNKNOWN&&r.valid_points==0);
    memset(images,127,sizeof images);
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_UNKNOWN&&r.valid_points==0);
    plane(64); // A disparity at the search boundary is not a valid distance.
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_UNKNOWN);
    c.camera[0].inverse_rectified[8]=0;
    r=stereo_measure(&c,read_pixel,0,140,30,120,120,0,&workspace);
    assert(r.status==STEREO_UNKNOWN);
    stereo_gate_t gate={0};
    assert(!stereo_gate_update(&gate,STEREO_NEAR,100,0));
    assert(stereo_gate_update(&gate,STEREO_NEAR,200,0));
    assert(stereo_gate_update(&gate,STEREO_UNKNOWN,400,0));
    assert(!stereo_gate_update(&gate,STEREO_UNKNOWN,1800,0));
    assert(!stereo_gate_update(&gate,STEREO_NEAR,1900,0));
    assert(stereo_gate_update(&gate,STEREO_NEAR,2000,0));
    assert(stereo_gate_update(&gate,STEREO_FAR,2100,0));
    assert(!stereo_gate_update(&gate,STEREO_FAR,2200,0));
    assert(!stereo_gate_update(&gate,STEREO_NEAR,0xfffffff0u,1));
    assert(!stereo_gate_update(&gate,STEREO_NEAR,0xfffffff0u,0));
    assert(stereo_gate_update(&gate,STEREO_NEAR,0xfffffff8u,0));
    assert(stereo_gate_update(&gate,STEREO_UNKNOWN,100,0));
    assert(!stereo_gate_update(&gate,STEREO_UNKNOWN,1600,0));
    puts("TEST_PASS stereo_depth near/far/boundary/quality/texture/search/invalid-map/hysteresis/wrap");
    return 0;
}
