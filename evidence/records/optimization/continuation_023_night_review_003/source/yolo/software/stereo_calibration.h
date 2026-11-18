#ifndef STEREO_CALIBRATION_H
#define STEREO_CALIBRATION_H
#include "stereo_depth.h"
/* No real calibration supplied yet. Never substitute the nominal 30mm
 * baseline for intrinsics, rectification or measured distance/sync evidence.
 * The exporter replaces this candidate file only after actual calibration. */
static const stereo_calibration_t stereo_calibration={.width=320,.height=180,
    .max_disparity=96,.max_skew_ms=5,.limit_mm=200,.error_mm=5,.verified=0};
#endif
