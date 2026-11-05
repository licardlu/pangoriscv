/* Host tests:
 *   cc -DBBOX_OSD_TEST platform_main.c test_bbox_osd.c -lm -o test_bbox_osd
 *   tcc -DBBOX_OSD_MMIO_TEST -run test_bbox_osd.c
 * The second form includes the real display_results with mocked MMIO.
 * The bundled TCC 0.9.25 needs its legacy math-header workaround flags:
 *   -D__NO_ISOCEXT -Disfinite=_finite "-DNAN=(0.0F/0.0F)"
 * These flags use the host CRT finite predicate; production math is unchanged. */
#include "yolo_decode.h"
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

extern int yolo_box_to_osd(const yolo_box_t *, uint32_t *, uint32_t *);
extern int yolo_osd_should_commit(const yolo_box_t *, uint32_t);

#ifdef BBOX_OSD_MMIO_TEST
static uint32_t mock_read(uint32_t);
static void mock_write(uint32_t, uint32_t);
static void mock_fence(void);
#define acc_rd mock_read
#define acc_wr mock_write
#define acc_fence mock_fence
#define POLL_LIMIT 8u
#define BBOX_OSD_TEST
#include "platform_main.c"
#undef acc_rd
#undef acc_wr
#undef acc_fence

static uint32_t staging[8], committed[8], selected;
static unsigned writes, commits, fences, reads, busy_reads, clears, coordinates;
static uint32_t mock_read(uint32_t off) {
    assert(off == 0x98);
    reads++;
    if (busy_reads) { busy_reads--; return 1; }
    return 0;
}
static void mock_write(uint32_t off, uint32_t value) {
    writes++;
    switch (off) {
    case 0x84: assert(value < 8); selected = value; break;
    case 0x88: case 0x8c: coordinates++; break;
    case 0x90:
        staging[selected] = value;
        if (!value) clears++;
        break;
    case 0x94:
        assert(value == 1);
        assert(selected == 7); /* All eight staging slots visited before commit. */
        memcpy(committed, staging, sizeof committed);
        commits++;
        break;
    default: assert(0);
    }
}
static void mock_fence(void) { fences++; }
static void reset_mmio(void) {
    unsigned i;
    writes = commits = fences = reads = busy_reads = clears = coordinates = 0;
    selected = 0;
    for (i = 0; i < 8; i++) staging[i] = committed[i] = 0x80000001u;
}
static void expect_empty_commit(void) {
    unsigned i;
    assert(commits == 1 && fences == 1 && clears == 8);
    assert(writes == 17 && coordinates == 0);
    for (i = 0; i < 8; i++) assert(committed[i] == 0);
}
static void test_display_commits(void) {
    unsigned i;
    /* Decode count=0 must clear even when boxes retain an older detection. */
    for (i = 0; i < YOLO_MAX_RESULTS; i++)
        boxes[i] = (yolo_box_t){10, 10, 20, 20, .9f, 2};
    reset_mmio();
    assert(display_results(0) == YOLO_OK);
    expect_empty_commit();
    /* Repeated successful misses must remain observable to the RTL. */
    assert(display_results(0) == YOLO_OK);
    assert(commits == 2 && fences == 2 && clears == 16);

    /* Non-empty decoder output may still contain no drawable boxes. */
    boxes[0] = (yolo_box_t){10, 10, 10, 20, .9f, 2};
    boxes[1] = (yolo_box_t){1280, 10, 1290, 20, .9f, 2};
    reset_mmio();
    assert(display_results(2) == YOLO_OK);
    expect_empty_commit();

    /* A new target replaces old slots after pending display work completes. */
    boxes[0] = (yolo_box_t){10, 10, 20, 20, .9f, 3};
    reset_mmio(); busy_reads = 3;
    assert(display_results(1) == YOLO_OK);
    assert(reads == 4 && commits == 1 && fences == 1);
    assert(coordinates == 2 && clears == 7 && committed[0] == 0x80000003u);
    for (i = 1; i < 8; i++) assert(committed[i] == 0);

    /* A busy timeout is an error, never a fabricated empty inference. */
    reset_mmio(); busy_reads = POLL_LIMIT;
    assert(display_results(0) == YOLO_TIMEOUT);
    assert(reads == POLL_LIMIT && !writes && !commits && !fences);
}
#endif

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
    {
        uint32_t xy1, xy2;
        assert(!yolo_box_to_osd(&(yolo_box_t){10, 10, 10, 20, .8f, 0}, &xy1, &xy2));
        assert(!yolo_box_to_osd(&(yolo_box_t){1280, 10, 1281, 20, .8f, 0}, &xy1, &xy2));
        assert(!yolo_box_to_osd(&(yolo_box_t){10, -20, 20, -1, .8f, 0}, &xy1, &xy2));
        assert(!yolo_box_to_osd(&(yolo_box_t){NAN, 0, 1, 1, .8f, 0}, &xy1, &xy2));
        assert(!yolo_box_to_osd(0, &xy1, &xy2));
    }
    {
        yolo_box_t valid = {10, 10, 20, 20, .9f, 2};
        yolo_box_t invalid[] = {
            {10, 10, 10, 20, .9f, 2},
            {1280, 10, 1290, 20, .9f, 2},
        };
        assert(yolo_osd_should_commit(&valid, 1)); /* New target replaces. */
        assert(yolo_osd_should_commit(0, 0));      /* Successful empty inference. */
        assert(yolo_osd_should_commit(invalid, 2)); /* Successful but not drawable. */
        assert(!yolo_osd_should_commit(0, 1));     /* Defensive null handling. */
    }
#ifdef BBOX_OSD_MMIO_TEST
    test_display_commits();
    puts("BBOX_OSD_MMIO_PASS empty/invalid commit, stale-slot clear, busy/timeout");
#endif
    puts("BBOX_OSD_PASS geometry and successful-empty commit policy");
    return 0;
}
