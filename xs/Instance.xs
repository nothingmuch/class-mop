#include "mop.h"

#define CHECK_INSTANCE(instance) STMT_START{                          \
        if(!(SvROK(instance) && SvTYPE(SvRV(instance)) == SVt_PVHV)){ \
            croak("Invalid object");                                  \
        }                                                             \
        if(SvTIED_mg(SvRV(instance), PERL_MAGIC_tied)){               \
            croak("MOP::Instance: tied HASH is not yet supported");   \
        }                                                             \
    } STMT_END

static SV*
mop_instance_create_instance(pTHX) {
    return newRV_noinc((SV*)newHV());
}

static bool
mop_instance_has_slot(pTHX_ SV* const instance, SV* const slot_name) {
    CHECK_INSTANCE(instance);
    return hv_exists_ent((HV*)SvRV(instance), slot_name, 0U);
}

static SV*
mop_instance_get_slot(pTHX_ SV* const instance, SV* const slot_name) {
    HE* he;
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot_name, FALSE, 0U);
    return he ? HeVAL(he) : NULL;
}

static SV*
mop_instance_set_slot(pTHX_ SV* const instance, SV* const slot_name, SV* const value) {
    HE* he;
    SV* sv;
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot_name, TRUE, 0U);
    sv = HeVAL(he);
    sv_setsv_mg(sv, value);
    return sv;
}

static SV*
mop_instance_delete_slot(pTHX_ SV* const instance, SV* const slot_name) {
    CHECK_INSTANCE(instance);
    return hv_delete_ent((HV*)SvRV(instance), slot_name, 0, 0U);
}

static void
mop_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot_name) {
    HE* he;
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot_name, FALSE, 0U);
    sv_rvweaken(HeVAL(he));
}

static const mop_instance_vtbl mop_default_instance = {
	mop_instance_create_instance,
	mop_instance_has_slot,
	mop_instance_get_slot,
	mop_instance_set_slot,
	mop_instance_delete_slot,
	mop_instance_weaken_slot,
};


const mop_instance_vtbl*
mop_get_default_instance_vtbl(pTHX){
    return &mop_default_instance;
}


MODULE = Class::MOP::Instance  PACKAGE = Class::MOP::Instance

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Instance, associated_metaclass);

void*
can_xs(SV* self)
PREINIT:
    SV* const can             = newSVpvs_flags("can", SVs_TEMP);
    SV* const default_class   = newSVpvs_flags("Class::MOP::Instance", SVs_TEMP);
    SV* const create_instance = newSVpvs_flags("create_instance", SVs_TEMP);
    SV* m1;
    SV* m2;
CODE:
    /* $self->can("create_instance") == Class::MOP::Instance->can("create_instance") */
    m1 = mop_call1(aTHX_ self,          can, create_instance);
    m2 = mop_call1(aTHX_ default_class, can, create_instance);
    if(SvROK(m1) && SvROK(m2) && SvRV(m1) == SvRV(m2)){
        RETVAL = (void*)&mop_default_instance;
    }
    else{
        RETVAL = NULL;
    }
OUTPUT:
    RETVAL

