#include "mop.h"

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

        if ( (he = hv_fetch_ent((HV *)SvRV(self), KEY_FOR(name), 0, HASH_FOR(name))) )
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

        if ( (he = hv_fetch_ent((HV *)SvRV(self), KEY_FOR(package_name), 0, HASH_FOR(package_name))) )
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

        if ( (he = hv_fetch_ent((HV *)SvRV(self), KEY_FOR(body), 0, HASH_FOR(body))) )
            XPUSHs(HeVAL(he));
        else
            ST(0) = &PL_sv_undef;
