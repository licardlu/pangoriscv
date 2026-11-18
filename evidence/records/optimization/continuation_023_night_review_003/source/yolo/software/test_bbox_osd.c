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
static uint32_t hold_state;
static unsigned hold_after_reads;
static uint32_t mock_read(uint32_t off) {
    assert(off == 0x98);
    reads++;
    if(reads>hold_after_reads)return hold_state;
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
    hold_state=0;hold_after_reads=UINT32_MAX;
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
    assert(reads == 5 && commits == 1 && fences == 1);
    assert(coordinates == 2 && clears == 7 && committed[0] == 0x80000003u);
    for (i = 1; i < 8; i++) assert(committed[i] == 0);

    /* A busy timeout is an error, never a fabricated empty inference. */
    reset_mmio(); busy_reads = POLL_LIMIT;
    assert(display_results(0) == YOLO_TIMEOUT);
    assert(reads == POLL_LIMIT && !writes && !commits && !fences);
    /* Existing and newly-arriving quiz/navigation ownership cancels a commit. */
    for(uint32_t bit=2;bit<=8;bit<<=1) {
        reset_mmio();hold_state=bit;hold_after_reads=0;
        assert(display_results(0)==YOLO_CANCELLED && !writes && !commits);
        reset_mmio();hold_state=bit;hold_after_reads=1;
        assert(display_results(0)==YOLO_CANCELLED && writes==16 && !commits && !fences);
    }
}
static void test_camera_probe(void) {
    uint32_t count;
    boxes[0]=(yolo_box_t){10,10,20,20,.99f,0};
    boxes[1]=(yolo_box_t){100,100,200,200,.8f,2};
    count=2;reset_mmio();busy_reads=POLL_LIMIT;
    assert(camera_results(&count,4,UINT32_MAX,1280,720,0)==YOLO_OK);
    assert(count==1 && boxes[0].category==2);
    assert(!reads && !writes && !commits && !fences);
    count=1;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(count==0 && camera_gate.hits==1 && !camera_gate.blocked);
    expect_empty_commit();
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};
    count=1;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(camera_gate.blocked);
    assert(commits==1 && committed[0]==0x80000002u);
    count=0;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,0)==YOLO_OK);
    assert(count==0 && !reads && !writes && !commits);
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    expect_empty_commit();
    assert(camera_gate.blocked && camera_gate.misses==1);
    /* Probe misses may not rearm or provide the second confirming observation. */
    count=0;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,0)==YOLO_OK);
    assert(camera_gate.blocked && camera_gate.misses==1);
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(!camera_gate.blocked);
    /* A hand with no contacting object suppresses remote background in both modes. */
    boxes[0]=(yolo_box_t){800,500,900,600,.99f,2};
    boxes[1]=(yolo_box_t){20,20,100,100,.9f,4};
    count=2;reset_mmio();
    assert(camera_results(&count,4,4,1280,720,0)==YOLO_OK);
    assert(count==0 && !writes && !commits);
    memset(&camera_gate,0,sizeof camera_gate);
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};
    count=1;reset_mmio();busy_reads=POLL_LIMIT;
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_TIMEOUT);
    assert(!camera_gate.hits && !camera_gate.blocked && !camera_gate.misses);
    /* Failed second confirmation must not consume the one-shot question. */
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};
    count=1;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(camera_gate.hits==1 && !camera_gate.blocked);
    yolo_camera_gate_t before=camera_gate;
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};
    count=1;reset_mmio();busy_reads=POLL_LIMIT;
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_TIMEOUT);
    assert(!memcmp(&before,&camera_gate,sizeof before) && !commits && !writes);
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};
    count=1;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(camera_gate.blocked && committed[0]==0x80000002u && commits==1);
    /* Failed second absence must not rearm an object still held by the UI. */
    count=0;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(camera_gate.blocked && camera_gate.misses==1);
    before=camera_gate;count=0;reset_mmio();busy_reads=POLL_LIMIT;
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_TIMEOUT);
    assert(!memcmp(&before,&camera_gate,sizeof before) && !commits && !writes);
    count=0;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    assert(!camera_gate.blocked && camera_gate.misses==2);
    /* Ownership changes after staging must not consume the confirming hit. */
    memset(&camera_gate,0,sizeof camera_gate);
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};count=1;reset_mmio();
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_OK);
    before=camera_gate;
    boxes[0]=(yolo_box_t){100,100,200,200,.8f,2};count=1;reset_mmio();
    hold_state=4;hold_after_reads=1;
    assert(camera_results(&count,4,UINT32_MAX,1280,720,1)==YOLO_CANCELLED);
    assert(!memcmp(&before,&camera_gate,sizeof before) && !commits);
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
    test_camera_probe();
    puts("BBOX_OSD_MMIO_PASS empty/invalid commit, stale-slot clear, busy/timeout, transactional confirmation/rearm, ownership cancellation");
#endif
    puts("BBOX_OSD_PASS geometry and successful-empty commit policy");
    return 0;
}
