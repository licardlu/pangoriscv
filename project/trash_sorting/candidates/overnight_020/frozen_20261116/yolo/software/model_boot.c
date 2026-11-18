#include "model_boot.h"
void model_boot_start(model_boot_state_t*s,model_boot_step_fn load,
                      model_boot_step_fn verify,void*context){
    s->verified=0;s->autonomous=0;
    s->error=load(context);
    if(!s->error)s->error=verify(context);
    if(!s->error){s->verified=1;s->autonomous=1;}
}
