#include "mop.h"

MODULE = Class::MOP::Instance  PACKAGE = Class::MOP::Instance

PROTOTYPES: DISABLE

void
create_c_instance (self)
        SV *self
    PREINIT:
        mop_instance_t *instance;
    CODE:
        instance = mop_instance_new_from_perl_instance (self);
        __asm__ __volatile__ ("int $03");
        if (instance) {
            mop_instance_destroy (instance);
        }
