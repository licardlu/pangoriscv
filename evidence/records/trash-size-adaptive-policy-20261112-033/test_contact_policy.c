#include "yolo_contact_policy.h"
#include <assert.h>
#include <stdio.h>

yolo_target_t policy_select_contact(const yolo_box_t *b,uint32_t n,
                                   const yolo_box_t *h,uint32_t hn,float w,float height)
{return yolo_select_contact_target_sets(b,n,h,hn,4,4,w,height);}

yolo_target_t policy_select(const yolo_box_t *b,uint32_t n,uint32_t classes,
                           uint32_t hand,float w,float h)
{return yolo_select_contact_target(b,n,classes,hand,w,h);}

int main(void)
{
    yolo_box_t hands[2]={{100,300,180,400,.8f,4},{800,300,900,400,.9f,4}};
    yolo_box_t objects[4]={{120,50,450,350,.8f,1}, /* Long bottle touches hand. */
                         {650,100,1100,600,.99f,3}, /* Remote clutter. */
                         {98,298,182,402,.99f,0}, /* Hand mistaken for waste. */
                         {0,0,1280,720,1.f,1}}; /* Whole-frame false box. */
    yolo_target_t t=policy_select_contact(objects,4,hands,1,1280,720);
    assert(t.object_index==0 && t.hand_seen && t.hand_index==0);
    assert(t.roi_x1==100 && t.roi_y1==50 && t.roi_x2==450 && t.roi_y2==400);
    objects[0]=(yolo_box_t){700,50,750,100,.8f,1};
    assert(policy_select_contact(objects,4,hands,1,1280,720).object_index==-1);
    objects[0]=(yolo_box_t){120,315,128,340,.3f,2}; /* Battery entirely in palm box. */
    assert(policy_select_contact(objects,4,hands,1,1280,720).object_index==0);
    assert(policy_select_contact(objects,2,hands,2,1280,720).object_index==1);
    assert(policy_select_contact(objects,2,0,0,1280,720).object_index==1);
    assert(policy_select_contact(0,0,hands,1,1280,720).hand_seen);
    assert(policy_select_contact(0,1,hands,1,1280,720).object_index==-1);
    assert(policy_select_contact(objects,2,hands,33,1280,720).object_index==-1);
    objects[0].score=NAN;
    assert(policy_select_contact(objects,1,hands,1,1280,720).object_index==-1);
    {
        yolo_box_t combined[4]={{100,300,180,400,.8f,4},
            {120,50,450,350,.8f,1},{650,100,1100,600,.99f,3},
            {98,298,182,402,.99f,0}};
        t=yolo_select_contact_target(combined,4,4,4,1280,720);
        assert(t.object_index==1 && t.hand_index==0 && t.hand_seen);
        combined[1]=(yolo_box_t){120,315,128,340,.3f,2};
        t=yolo_select_contact_target(combined,4,4,4,1280,720);
        assert(t.object_index==1 && combined[t.object_index].category==2);
        /* Existing four-class model has no locator; retain maximum area. */
        t=yolo_select_contact_target(combined+1,3,4,UINT32_MAX,1280,720);
        assert(t.object_index==1 && !t.hand_seen);
    }
    {
        yolo_box_t tied[3]={{-100,0,20,20,.95f,1},
            {30,0,50,20,.4f,2},{60,0,80,20,.7f,3}};
        /* Compare clipped area first, confidence only for equal areas. */
        assert(policy_select_contact(tied,3,0,0,100,100).object_index==0);
        tied[0].x2=19;
        assert(policy_select_contact(tied,3,0,0,100,100).object_index==2);
    }
    {
        yolo_box_t h={100,100,120,120,.9f,4}; /* Hand area400. */
        yolo_box_t large={110,0,210,120,.6f,1};
        /* Box extends far beyond hand ROI; keep its ORIGINAL full bounds. */
        t=policy_select_contact(&large,1,&h,1,640,480);
        assert(t.object_index==0 && t.roi_x2==210 && t.roi_y1==0);
        assert(large.x1==110 && large.x2==210 && large.y1==0 && large.y2==120);
        yolo_box_t palm={105,103,110,110,.4f,2};
        assert(policy_select_contact(&palm,1,&h,1,640,480).object_index==0);
        yolo_box_t edge={112,79,120,120,.99f,3};
        /* Hand contact passes, but only73% is in the local ROI. The size
         * branch must reject it; contact alone used to admit this box. */
        assert(policy_select_contact(&edge,1,&h,1,640,480).object_index==-1);
    }
    {
        yolo_box_t h[3]={{100,100,120,120,.9f,4},
            {500,400,540,440,.8f,4},{0,0,640,480,NAN,4}};
        yolo_box_t o={110,20,120,120,.6f,1}; /* Area1000, mean(400,1600)=1000. */
        /* Equality belongs to small/local mode, not the large exception. */
        assert(policy_select_contact(&o,1,h,3,640,480).object_index==-1);
        o.y1=19;
        assert(policy_select_contact(&o,1,h,3,640,480).object_index==0);
        /* Removing the larger hand changes the CURRENT-frame mean to400. */
        o.y1=20;
        assert(policy_select_contact(&o,1,h,1,640,480).object_index==0);
        /* Invalid/wrong-class boxes never contribute to the mean. */
        h[1].category=1;
        assert(policy_select_contact(&o,1,h,3,640,480).object_index==0);
    }
    {
        yolo_box_t h={-100,100,20,120,.9f,4}; /* Clipped area400, not2400. */
        yolo_box_t o={10,20,20,120,.6f,1}; /* Area1000 => large. */
        assert(policy_select_contact(&o,1,&h,1,640,480).object_index==0);
    }
    puts("TEST_PASS contact_policy long_object/palm_battery/clutter/hand_duplicate/invalid/no_hand/multihand/combined_camera/clipped_area_ties/size_adaptive/full_large_box/mean_valid_hands/equal_area/clipped_hand");
    return 0;
}
