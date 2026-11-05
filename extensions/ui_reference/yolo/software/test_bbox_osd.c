#include "yolo_decode.h"
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

extern int yolo_box_to_osd(const yolo_box_t *, uint32_t *, uint32_t *);

static uint32_t pack(unsigned x, unsigned y) { return x | (y << 16); }
static void expect_box(yolo_box_t box, uint32_t xy1, uint32_t xy2) {
    uint32_t got1 = 0, got2 = 0;
    assert(yolo_box_to_osd(&box, &got1, &got2) == 1);
    assert(got1 == xy1);
    assert(got2 == xy2);
}

int main(void) {
    expect_box((yolo_box_t){10.0f, 20.0f, 20.0f, 30.0f, .8f, 0},
               pack(10, 20), pack(19, 29));
    expect_box((yolo_box_t){10.25f, 20.25f, 20.25f, 30.25f, .8f, 0},
               pack(10, 20), pack(20, 30));
    expect_box((yolo_box_t){0.0f, 0.0f, 1280.0f, 720.0f, .8f, 0},
               pack(0, 0), pack(1279, 719));
    expect_box((yolo_box_t){-0.5f, -1.0f, 0.5f, 1.0f, .8f, 0},
               pack(0, 0), pack(0, 0));
    expect_box((yolo_box_t){1279.1f, 719.1f, 1280.5f, 720.5f, .8f, 0},
               pack(1279, 719), pack(1279, 719));
    assert(!yolo_box_to_osd(&(yolo_box_t){10, 10, 10, 20, .8f, 0}, 0, 0));
    assert(!yolo_box_to_osd(&(yolo_box_t){1280, 10, 1281, 20, .8f, 0}, 0, 0));
    assert(!yolo_box_to_osd(&(yolo_box_t){10, -20, 20, -1, .8f, 0}, 0, 0));
    assert(!yolo_box_to_osd(&(yolo_box_t){NAN, 0, 1, 1, .8f, 0}, 0, 0));
    puts("BBOX_OSD_PASS exclusive float edges -> inclusive 1280x720 pixels");
    return 0;
}
