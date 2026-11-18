#ifndef SORTING_PLATFORM_H
#define SORTING_PLATFORM_H
#include "io.h"
#include "app_yolo.h"
#include "service.h"

uint32_t platform_ms(void);
void platform_log(const char *);
void platform_idle(void);
int platform_init(System *);
void platform_poll(System *);
int platform_model_load(void);
int platform_infer(System *);

#endif
