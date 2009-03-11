#include "mop.h"

MODULE = Class::MOP::Attribute   PACKAGE = Class::MOP::Attribute

PROTOTYPES: DISABLE

void
name(self)
    SV *self
    PREINIT:
        register HE *he;
    PPCODE:
        if ( ! SvROK(self) ) {
            die("Cannot call name as a class method");
        }

        if ( (he = hv_fetch_ent((HV *)SvRV(self), KEY_FOR(name), 0, HASH_FOR(name))) )
            XPUSHs(HeVAL(he));
        else
            ST(0) = &PL_sv_undef;
