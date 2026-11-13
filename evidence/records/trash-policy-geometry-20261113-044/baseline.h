#ifndef YOLO_CONTACT_POLICY_H
#define YOLO_CONTACT_POLICY_H
#include "yolo_target_policy.h"

/* Small objects use a local hand ROI; large objects may extend beyond it.
 * Scale reference is mean valid clipped hand area in THIS frame, never a
 * fixed pixel size or a running mean from a different camera distance.
 * Bounding-box overlap is only a contact candidate, not proof of
 * grasping. Model validation and final board acceptance remain separate gates.
 * Waste and hand Top-K remain independent. No hand: exact largest rule.
 */
static inline yolo_target_t yolo_select_contact_target_sets(
    const yolo_box_t *boxes,uint32_t count,const yolo_box_t *hands,uint32_t hand_count,
    uint32_t waste_classes,uint32_t hand_class,float width,float height)
{
    yolo_target_t result={-1,-1,0,0,0,0,0};
    yolo_box_t hand,object;
    uint32_t i,j,valid_hands=0;
    float mean_hand_area=0;
    float best_score=-1,best_contact=-1,best_hand_score=-1;
    if((!boxes&&count)||(!hands&&hand_count)||count>YOLO_MAX_RESULTS||
       hand_count>YOLO_MAX_RESULTS||!isfinite(width)||!isfinite(height)||
       width<=0||height<=0) return result;
    for(i=0;i<hand_count;i++) {
        if(hands[i].category==hand_class && hand_class>=waste_classes &&
           target_clip(&hands[i],width,height,&hand)) {
            mean_hand_area+=target_area(&hand);
            valid_hands++;
        }
    }
    if(valid_hands) mean_hand_area/=valid_hands;
    for(i=0;i<hand_count;i++) {
        if(hands[i].category!=hand_class||hand_class<waste_classes||
           !target_clip(&hands[i],width,height,&hand)) continue;
        result.hand_seen=1;
        if(result.object_index<0 && hand.score>best_hand_score) {
            result.hand_index=(int)i;best_hand_score=hand.score;
            result.roi_x1=hand.x1;result.roi_y1=hand.y1;
            result.roi_x2=hand.x2;result.roi_y2=hand.y2;
        }
        for(j=0;j<count;j++) {
            float overlap,area,hand_area,small,contact;
            if(boxes[j].category>=waste_classes||
               !target_clip(&boxes[j],width,height,&object)) continue;
            area=target_area(&object);hand_area=target_area(&hand);
            overlap=target_intersection(&object,&hand);
            small=target_min(area,hand_area);
            if(overlap<small*.1f || overlap>=(area+hand_area-overlap)*.65f ||
               area>width*height*.9f) continue;
            if(area<=mean_hand_area) {
                yolo_box_t roi=hand;
                float cx=(object.x1+object.x2)*.5f;
                float cy=(object.y1+object.y2)*.5f;
                roi.x1=target_max(0,hand.x1-(hand.x2-hand.x1)*.5f);
                roi.x2=target_min(width,hand.x2+(hand.x2-hand.x1)*.5f);
                roi.y1=target_max(0,hand.y1-(hand.y2-hand.y1)*.5f);
                roi.y2=target_min(height,hand.y2+(hand.y2-hand.y1)*.5f);
                if(cx<roi.x1||cx>=roi.x2||cy<roi.y1||cy>=roi.y2||
                   target_intersection(&object,&roi)<area*.75f) continue;
            }
            /* For a larger box, contact is enough: never truncate it to the
             * hand ROI. The camera caller submits the original object box. */
            contact=overlap/small;
            if(object.score>best_score || (object.score==best_score &&
               (contact>best_contact || (contact==best_contact && hand.score>best_hand_score)))) {
                best_score=object.score;best_contact=contact;best_hand_score=hand.score;
                result.object_index=(int)j;result.hand_index=(int)i;
                result.roi_x1=target_min(hand.x1,object.x1);
                result.roi_y1=target_min(hand.y1,object.y1);
                result.roi_x2=target_max(hand.x2,object.x2);
                result.roi_y2=target_max(hand.y2,object.y2);
            }
        }
    }
    if(result.hand_seen) return result;
    return yolo_select_target_sets(boxes,count,0,0,waste_classes,hand_class,width,height);
}

/* Combined-list camera entry: preserve original indices just like the ROI
 * selector. The decoder's static-image numerical replies remain unfiltered. */
static inline yolo_target_t yolo_select_contact_target(
    const yolo_box_t *boxes,uint32_t count,uint32_t waste_classes,
    uint32_t hand_class,float width,float height)
{
    return yolo_select_contact_target_sets(boxes,count,boxes,count,
                                          waste_classes,hand_class,width,height);
}
#endif
