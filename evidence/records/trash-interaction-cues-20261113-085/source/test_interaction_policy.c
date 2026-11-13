#include "yolo_interaction_policy.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

yolo_cue_target_t policy_select_cues(const yolo_box_t *b,uint32_t n,
                                    const yolo_box_t *c,uint32_t cn,float w,float h)
{return yolo_select_cue_target(b,n,c,cn,w,h);}

int main(void)
{
    yolo_box_t objects[3]={{100,100,300,400,.5f,1},
        {350,0,640,480,.99f,3},{100,100,300,400,.7f,2}};
    yolo_box_t snapshot[3];memcpy(snapshot,objects,sizeof objects);
    yolo_box_t cue={105,105,295,395,.8f,0};
    yolo_cue_target_t t=policy_select_cues(objects,3,&cue,1,640,480);
    assert(t.object_index==2&&t.cue_seen&&!t.empty_hand);
    assert(!memcmp(snapshot,objects,sizeof objects)); /* Full original bounds retained. */
    cue.category=1;
    t=policy_select_cues(objects,3,&cue,1,640,480);
    assert(t.object_index==-1&&t.empty_hand&&t.cue_seen);
    assert(policy_select_cues(objects,3,0,0,640,480).object_index==1);
    cue=(yolo_box_t){0,0,10,10,.8f,0};
    assert(policy_select_cues(objects,3,&cue,1,640,480).object_index==-1);
    cue.category=2; /* Unknown cue cannot create an empty-hand veto. */
    assert(policy_select_cues(objects,3,&cue,1,640,480).object_index==1);
    cue.category=0;cue.score=NAN;
    assert(policy_select_cues(objects,3,&cue,1,640,480).object_index==1);
    cue=(yolo_box_t){-100,-100,300,400,.8f,0};
    assert(policy_select_cues(objects,3,&cue,1,640,480).object_index==2);
    {
        yolo_box_t cues[2]={{350,0,640,480,.7f,0},{100,100,300,400,.8f,0}};
        assert(policy_select_cues(objects,3,cues,2,640,480).object_index==2);
        cues[0].category=1;
        assert(policy_select_cues(objects,3,cues,2,640,480).object_index==2);
    }
    assert(policy_select_cues(0,1,&cue,1,640,480).object_index==-1);
    assert(policy_select_cues(objects,33,&cue,1,640,480).object_index==-1);
    assert(policy_select_cues(objects,3,&cue,1,NAN,480).object_index==-1);
    puts("TEST_PASS interaction_cue_policy full_box/clutter/score_tie/empty/nohand/low_overlap/unknown/invalid/clipping/multiple");
    return 0;
}
