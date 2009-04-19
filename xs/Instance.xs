#include "mop.h"

MODULE = Class::MOP::Instance  PACKAGE = Class::MOP::Instance

PROTOTYPES: DISABLE

void
create_c_instance (self)
        SV *self
    PREINIT:
        mop_instance_t *instance;
    CODE:
        (void)mop_instance_get_c_instance(self);

