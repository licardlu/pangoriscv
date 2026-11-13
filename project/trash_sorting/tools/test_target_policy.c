#include "yolo_target_policy.h"
#include <assert.h>
#include <stdio.h>

/* Also export the exact policy for offline model evaluations via ctypes. */
yolo_target_t policy_select(const yolo_box_t *b,uint32_t n,uint32_t classes,
                           uint32_t hand,float w,float h)
{return yolo_select_target(b,n,classes,hand,w,h);}

yolo_target_t policy_select_separate(const yolo_box_t *b,uint32_t n,
                                    const yolo_box_t *hands,uint32_t hn,float w,float h)
{return yolo_select_target_sets(b,n,hands,hn,4,4,w,h);}

int main(void)
{
    yolo_box_t b[5]={{0,0,100,100,.3f,1},{200,200,210,210,.99f,2}};
    yolo_target_t t=policy_select(b,2,4,4,1280,720);
    assert(t.object_index==0 && !t.hand_seen); /* Larger beats confidence. */
    b[0]=(yolo_box_t){-100,-100,10,10,.99f,0};
    b[1]=(yolo_box_t){50,50,70,70,.3f,3};
    assert(policy_select(b,2,4,4,1280,720).object_index==1); /* Clipped area. */
    b[0]=(yolo_box_t){400,200,500,300,.8f,4};
    b[1]=(yolo_box_t){470,190,482,225,.3f,2}; /* Small held-item candidate. */
    b[2]=(yolo_box_t){800,50,1200,600,.99f,1}; /* Remote large clutter. */
    b[3]=(yolo_box_t){390,190,510,310,.99f,0}; /* Hand hallucinated as kitchen. */
    b[4]=(yolo_box_t){100,50,1100,700,.99f,1}; /* Encloses hand and scene. */
    t=policy_select(b,5,4,4,1280,720);
    assert(t.object_index==1 && t.hand_seen && t.hand_index==0);
    b[1].x1=800;b[1].x2=812;
    assert(policy_select(b,5,4,4,1280,720).object_index==-1);
    b[0]=(yolo_box_t){0,0,30,30,.9f,4};
    b[1]=(yolo_box_t){20,5,26,15,.4f,2};
    t=policy_select(b,2,4,4,1280,720);
    assert(t.object_index==1 && t.roi_x1==0 && t.roi_y1==0);
    b[2]=(yolo_box_t){200,200,300,300,.9f,4};
    b[3]=(yolo_box_t){245,245,251,257,.7f,1};
    assert(policy_select(b,4,4,4,1280,720).object_index==3); /* Multiple hands. */
    b[0].x1=NAN;b[1].score=NAN;b[2].category=255;b[3].x2=b[3].x1;
    assert(policy_select(b,4,4,4,1280,720).object_index==-1);
    assert(policy_select(0,0,4,4,1280,720).object_index==-1);
    assert(policy_select(b,YOLO_MAX_RESULTS+1,4,4,1280,720).object_index==-1);
    assert(policy_select(b,1,4,4,INFINITY,720).object_index==-1);
    b[0]=(yolo_box_t){0,0,10,10,.3f,0};
    b[1]=(yolo_box_t){20,20,30,30,.8f,1};
    assert(policy_select(b,2,4,UINT32_MAX,1280,720).object_index==1);
    {
        yolo_box_t objects[YOLO_MAX_RESULTS],hands[2]={{400,200,500,300,.8f,4},{900,500,950,550,.7f,4}};
        uint32_t i;
        for(i=0;i<YOLO_MAX_RESULTS;i++) objects[i]=(yolo_box_t){50,50,100,100,.99f,1};
        objects[31]=(yolo_box_t){470,190,482,225,.3f,2};
        t=policy_select_separate(objects,32,hands,2,1280,720);
        assert(t.object_index==31 && t.hand_index==0 && t.hand_seen);
        assert(policy_select_separate(objects,32,0,0,1280,720).object_index==0);
        assert(policy_select_separate(0,0,hands,2,1280,720).object_index==-1);
        assert(policy_select_separate(0,1,hands,2,1280,720).hand_seen==0);
        assert(policy_select_separate(objects,32,0,1,1280,720).hand_seen==0);
        assert(policy_select_separate(objects,32,hands,33,1280,720).object_index==-1);
    }
    puts("TEST_PASS target_policy largest/clipping/hand/empty/multihand/invalid/separate_TopK");
    return 0;
}
