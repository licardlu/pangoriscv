#ifndef APP_YOLO_H
#define APP_YOLO_H
#include <stdint.h>
typedef struct {float ratio,pad_x,pad_y;} AppLetterbox;
unsigned app_yolo_bin(unsigned category);
int app_yolo_preprocess(const uint16_t *,unsigned,unsigned,int8_t *,AppLetterbox *);
#endif
