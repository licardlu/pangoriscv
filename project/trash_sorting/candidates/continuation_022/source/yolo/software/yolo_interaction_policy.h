#ifndef YOLO_INTERACTION_POLICY_H
#define YOLO_INTERACTION_POLICY_H
#include "yolo_target_policy.h"

/* Offline candidate only. Cues describe the HELD ITEM or an EMPTY hand;
 * a plain hand box cannot be substituted for a held-item annotation. */
typedef struct {
    int object_index;
    int cue_index;
    uint32_t cue_seen;
    uint32_t empty_hand;
} yolo_cue_target_t;

static inline yolo_cue_target_t yolo_select_cue_target(
    const yolo_box_t *objects,uint32_t count,const yolo_box_t *cues,
    uint32_t cue_count,float width,float height)
{
    yolo_cue_target_t result={-1,-1,0,0};
    yolo_box_t cue,held,object;
    float held_score=-1,held_area=-1,best_iou=-1,best_score=-1,best_area=-1;
    uint32_t i;
    if((!objects&&count)||(!cues&&cue_count)||count>YOLO_MAX_RESULTS||
       cue_count>YOLO_MAX_RESULTS||!isfinite(width)||!isfinite(height)||
       width<=0||height<=0) return result;
    for(i=0;i<cue_count;i++) {
        float a;
        if(cues[i].category>1||!target_clip(&cues[i],width,height,&cue)) continue;
        result.cue_seen=1;
        if(cues[i].category==1) {result.empty_hand=1;continue;}
        a=target_area(&cue);
        if(cue.score>held_score||(cue.score==held_score&&a>held_area)) {
            held=cue;held_score=cue.score;held_area=a;result.cue_index=(int)i;
        }
    }
    if(result.cue_index>=0) {
        result.empty_hand=0;
        for(i=0;i<count;i++) {
            float overlap,total,match,a;
            if(objects[i].category>=4||!target_clip(&objects[i],width,height,&object)) continue;
            a=target_area(&object);overlap=target_intersection(&object,&held);
            total=a+held_area-overlap;match=total>0?overlap/total:0;
            if(match<.25f) continue;
            if(match>best_iou||(match==best_iou&&(object.score>best_score||
               (object.score==best_score&&a>best_area)))) {
                result.object_index=(int)i;best_iou=match;best_score=object.score;best_area=a;
            }
        }
    } else if(!result.cue_seen) {
        result.object_index=yolo_select_target_sets(objects,count,0,0,4,UINT32_MAX,width,height).object_index;
    }
    return result;
}
#endif
