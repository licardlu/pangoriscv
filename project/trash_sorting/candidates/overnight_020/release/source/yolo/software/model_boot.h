#ifndef MODEL_BOOT_H
#define MODEL_BOOT_H
#include <stdint.h>
typedef struct {uint8_t verified,autonomous;int error;} model_boot_state_t;
typedef int (*model_boot_step_fn)(void*);
void model_boot_start(model_boot_state_t*,model_boot_step_fn,model_boot_step_fn,void*);
#endif
