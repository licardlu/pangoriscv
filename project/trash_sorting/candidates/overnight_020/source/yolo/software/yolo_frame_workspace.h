#ifndef YOLO_FRAME_WORKSPACE_H
#define YOLO_FRAME_WORKSPACE_H
#include "yolo_decode.h"

/* Acquisition -> graph execution -> decoding are strictly sequential.
 * Nothing stored here survives a phase transition. Runtime callbacks must
 * not re-enter acquisition/decoding, nor may an interrupt run these stages.
 * Persistent boxes/config/profile remain outside this shared storage.
 */
typedef union {
    yolo_decode_workspace_t decode;
    uint8_t input_row[320u*8u];
} yolo_frame_workspace_t;

#if defined(VEXII_PLATFORM) || !defined(__riscv)
yolo_frame_workspace_t *yolo_frame_workspace_get(void);
#endif
#endif
