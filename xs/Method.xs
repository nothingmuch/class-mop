#include "mop.h"

NEEDS_KEY(name);
NEEDS_KEY(body);
NEEDS_KEY(package_name);

MODULE = Class::MOP::Method   PACKAGE = Class::MOP::Method

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

        if ( (he = hv_fetch_ent((HV *)SvRV(self), key_name, 0, hash_name)) )
            XPUSHs(HeVAL(he));
        else
            ST(0) = &PL_sv_undef;

void
package_name(self)
    SV *self
    PREINIT:
        register HE *he;
    PPCODE:
        if ( ! SvROK(self) ) {
            die("Cannot call package_name as a class method");
        }

        if ( (he = hv_fetch_ent((HV *)SvRV(self), key_package_name, 0, hash_package_name)) )
            XPUSHs(HeVAL(he));
        else
            ST(0) = &PL_sv_undef;

void
body(self)
    SV *self
    PREINIT:
        register HE *he;
    PPCODE:
        if ( ! SvROK(self) ) {
            die("Cannot call body as a class method");
        }

        if ( (he = hv_fetch_ent((HV *)SvRV(self), key_body, 0, hash_body)) )
            XPUSHs(HeVAL(he));
        else
            ST(0) = &PL_sv_undef;
