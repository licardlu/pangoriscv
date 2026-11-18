#ifndef YOLO_TARGET_POLICY_H
#define YOLO_TARGET_POLICY_H
#include "yolo_decode.h"
#include <math.h>

#ifndef YOLO_SCENE_MIN_WASTE_SCORE
#define YOLO_SCENE_MIN_WASTE_SCORE 0.30f
#endif

/* Internal class 4 is hand only for a five-class checkpoint. Never send it
 * to the bin mapper. Four-class checkpoints use UINT32_MAX (no hand output).
 * Geometry is a candidate association, not proof that a hand holds an object.
 */
typedef struct {
    int object_index, hand_index;
    unsigned hand_seen;
    float roi_x1,roi_y1,roi_x2,roi_y2;
} yolo_target_t;

static inline float target_min(float a,float b) {return a<b?a:b;}
static inline float target_max(float a,float b) {return a>b?a:b;}
static inline float target_area(const yolo_box_t *b)
{return (b->x2-b->x1)*(b->y2-b->y1);}
static inline float target_intersection(const yolo_box_t *a,const yolo_box_t *b)
{
    return target_max(0,target_min(a->x2,b->x2)-target_max(a->x1,b->x1))*
           target_max(0,target_min(a->y2,b->y2)-target_max(a->y1,b->y1));
}
static inline int target_clip(const yolo_box_t *b,float w,float h,yolo_box_t *out)
{
    if(!isfinite(b->x1)||!isfinite(b->y1)||!isfinite(b->x2)||!isfinite(b->y2)||
       !isfinite(b->score)||b->score<0||b->score>1||b->x2<=b->x1||b->y2<=b->y1) return 0;
    *out=*b;
    out->x1=target_max(0,target_min(w,b->x1));
    out->x2=target_max(0,target_min(w,b->x2));
    out->y1=target_max(0,target_min(h,b->y1));
    out->y2=target_max(0,target_min(h,b->y2));
    return out->x2>out->x1 && out->y2>out->y1;
}

/* A bounded scan, no image buffer or extra neural inference. With no hand,
 * area is the primary key (not confidence). With hands, keep centers in the
 * expanded hand ROI and >=75% of the object inside it; reject near-identical
 * hand/waste boxes and boxes covering most of the ROI. Then prefer the object
 * closest to its hand, breaking ties by confidence. Parameters are fixed for
 * the initial offline prototype and must be checked on held-item scenes.
 */
/* Separate lists preserve all waste candidates when an auxiliary hand head
 * is used; hands must not steal the waste detector's Top-K capacity. The
 * indices refer to their respective lists. The legacy wrapper below passes
 * the same list twice and preserves its original combined-list indices. */
static inline yolo_target_t yolo_select_target_sets(const yolo_box_t *boxes,uint32_t count,
                                              const yolo_box_t *hands,uint32_t hand_count,
                                              uint32_t waste_classes,uint32_t hand_class,
                                              float width,float height)
{
    yolo_target_t result={-1,-1,0,0,0,0,0};
    yolo_box_t hand,object,roi;
    uint32_t i,j;
    float best_area=-1,best_score=-1,best_distance=1e30f,hand_score=-1;
    if((!boxes&&count)||(!hands&&hand_count)||count>YOLO_MAX_RESULTS||
       hand_count>YOLO_MAX_RESULTS||!isfinite(width)||!isfinite(height)||
       width<=0||height<=0) return result;
    for(i=0;i<hand_count;i++) {
        if(hands[i].category!=hand_class||hand_class<waste_classes||
           !target_clip(&hands[i],width,height,&hand)) continue;
        result.hand_seen=1;
        roi=hand;
        roi.x1=target_max(0,hand.x1-(hand.x2-hand.x1)*.5f);
        roi.x2=target_min(width,hand.x2+(hand.x2-hand.x1)*.5f);
        roi.y1=target_max(0,hand.y1-(hand.y2-hand.y1)*.5f);
        roi.y2=target_min(height,hand.y2+(hand.y2-hand.y1)*.5f);
        if(result.object_index<0 && hand.score>hand_score) {
            result.hand_index=(int)i;hand_score=hand.score;
            result.roi_x1=roi.x1;result.roi_y1=roi.y1;
            result.roi_x2=roi.x2;result.roi_y2=roi.y2;
        }
        for(j=0;j<count;j++) {
            float area,overlap,union_area,cx,cy,dx,dy,distance;
            if(boxes[j].category>=waste_classes||!target_clip(&boxes[j],width,height,&object)) continue;
            area=target_area(&object);
            cx=(object.x1+object.x2)*.5f;cy=(object.y1+object.y2)*.5f;
            if(cx<roi.x1||cx>=roi.x2||cy<roi.y1||cy>=roi.y2||
               target_intersection(&object,&roi)<area*.75f||area>target_area(&roi)*.8f) continue;
            overlap=target_intersection(&object,&hand);
            union_area=area+target_area(&hand)-overlap;
            if(overlap>=union_area*.65f) continue;
            dx=(cx-(hand.x1+hand.x2)*.5f)/(hand.x2-hand.x1);
            dy=(cy-(hand.y1+hand.y2)*.5f)/(hand.y2-hand.y1);
            distance=dx*dx+dy*dy;
            if(distance<best_distance || (distance==best_distance && object.score>best_score)) {
                best_distance=distance;best_score=object.score;
                result.object_index=(int)j;result.hand_index=(int)i;
                result.roi_x1=roi.x1;result.roi_y1=roi.y1;
                result.roi_x2=roi.x2;result.roi_y2=roi.y2;
            }
        }
    }
    if(result.hand_seen) return result; /* Empty hand must not select clutter. */
    for(i=0;i<count;i++) {
        float area;
        if(boxes[i].category>=waste_classes||boxes[i].score<YOLO_SCENE_MIN_WASTE_SCORE||!target_clip(&boxes[i],width,height,&object)) continue;
        area=target_area(&object);
        if(area>best_area || (area==best_area && object.score>best_score)) {
            best_area=area;best_score=object.score;result.object_index=(int)i;
        }
    }
    return result;
}

static inline yolo_target_t yolo_select_target(const yolo_box_t *boxes,uint32_t count,
                                              uint32_t waste_classes,uint32_t hand_class,
                                              float width,float height)
{
    return yolo_select_target_sets(boxes,count,boxes,count,waste_classes,hand_class,width,height);
}
#endif
