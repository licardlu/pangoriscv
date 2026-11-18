#ifndef STEREO_DEPTH_H
#define STEREO_DEPTH_H
#include <stdint.h>
#define STEREO_MAX_DISPARITY 96
#define STEREO_BAND (STEREO_MAX_DISPARITY+5)
enum {STEREO_UNKNOWN=0,STEREO_NEAR=1,STEREO_FAR=2};
enum {STEREO_CALIBRATED=1,STEREO_DISTANCE_VERIFIED=2,STEREO_SYNC_VERIFIED=4};
typedef struct {
    float fx,fy,cx,cy,dist[5],inverse_rectified[9],forward_rectified[9];
} stereo_camera_t;
typedef struct {
    stereo_camera_t camera[2];
    uint16_t width,height,max_disparity,max_skew_ms;
    uint16_t limit_mm,error_mm;
    uint32_t focal_baseline_q8;
    uint8_t verified;
} stereo_calibration_t;
typedef struct {
    uint8_t band[5*STEREO_BAND],valid[5*STEREO_BAND],patch[25];
    uint16_t depths[9],uncertainty[9];
} stereo_workspace_t;
typedef int (*stereo_raw_read_t)(void*,unsigned,int,int,uint8_t*);
typedef struct {
    uint8_t status,valid_points,total_points;
    uint16_t median_mm,low_mm,high_mm,uncertainty_mm;
} stereo_measurement_t;
/* Input ROI is in RECTIFIED left coordinates. Reader supplies frozen RAW
 * grayscale views. No frame buffer allocations or hardware access here. */
stereo_measurement_t stereo_measure(const stereo_calibration_t*,stereo_raw_read_t,void*,
                                  int x,int y,int w,int h,uint32_t skew_ms,
                                  stereo_workspace_t*);
int stereo_rectified_roi(const stereo_calibration_t*,int x,int y,int w,int h,int result[4]);
typedef struct {uint8_t near_count,far_count,active;uint32_t last_near_ms;} stereo_gate_t;
/* UNKNOWN never confirms a near object. It may retain a display for 1500ms,
 * but callers must require a fresh NEAR measurement before committing a quiz. */
int stereo_gate_update(stereo_gate_t*,unsigned observation,uint32_t now_ms,int reset);
#endif
