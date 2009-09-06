#include "mop.h"

#define CHECK_INSTANCE(instance) STMT_START{                          \
        if(!(SvROK(instance) && SvTYPE(SvRV(instance)) == SVt_PVHV)){ \
            croak("Invalid object for instance managers");            \
        }                                                             \
    } STMT_END

SV*
mop_instance_create(pTHX_ HV* const stash) {
    assert(stash);
    return sv_bless( newRV_noinc((SV*)newHV()), stash );
}

SV*
mop_instance_clone(pTHX_ SV* const instance) {
    HV* proto;
    assert(instance);

    CHECK_INSTANCE(instance);
    proto = newHVhv((HV*)SvRV(instance));
    return sv_bless( newRV_noinc((SV*)proto), SvSTASH(SvRV(instance)) );
}



bool
mop_instance_has_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_exists_ent((HV*)SvRV(instance), slot, 0U);
}

SV*
mop_instance_get_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    return he ? HeVAL(he) : NULL;
}

SV*
mop_instance_set_slot(pTHX_ SV* const instance, SV* const slot, SV* const value) {
    HE* he;
    SV* sv;
    assert(instance);
    assert(slot);
    assert(value);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, TRUE, 0U);
    sv = HeVAL(he);
    sv_setsv_mg(sv, value);
    return sv;
}

SV*
mop_instance_delete_slot(pTHX_ SV* const instance, SV* const slot) {
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    return hv_delete_ent((HV*)SvRV(instance), slot, 0, 0U);
}

void
mop_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot) {
    HE* he;
    assert(instance);
    assert(slot);
    CHECK_INSTANCE(instance);
    he = hv_fetch_ent((HV*)SvRV(instance), slot, FALSE, 0U);
    if(he){
        sv_rvweaken(HeVAL(he));
    }
}

static const mop_instance_vtbl mop_default_instance = {
    mop_instance_create,
    mop_instance_clone,
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

VERSIONCHECK: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Instance, associated_metaclass);

void*
can_xs(SV* self)
PREINIT:
    CV* const default_method  = get_cv("Class::MOP::Instance::get_slot_value", FALSE);
    SV* const method          = newSVpvs_flags("get_slot_value", SVs_TEMP);
    SV* code_ref;
CODE:
    /* $self->can("get_slot_value") == \&Class::MOP::Instance::get_slot_value */
    code_ref = mop_call1(aTHX_ self, mop_can, method);
    if(SvROK(code_ref) && SvRV(code_ref) == (SV*)default_method){
        RETVAL = (void*)&mop_default_instance;
    }
    else{
        RETVAL = NULL;
    }
OUTPUT:
    RETVAL

SV*
create_instance(SV* self)
PREINIT:
    SV* class_name;
CODE:
    class_name = mop_call0_pvs(self, "_class_name");
    RETVAL = mop_instance_create(aTHX_ gv_stashsv(class_name, TRUE));
OUTPUT:
    RETVAL

SV*
clone_instance(SV* self, SV* instance)
CODE:
    PERL_UNUSED_VAR(self);
    RETVAL = mop_instance_clone(aTHX_ instance);
OUTPUT:
    RETVAL

bool
is_slot_initialized(SV* self, SV* instance, SV* slot)
CODE:
    PERL_UNUSED_VAR(self);
    RETVAL = mop_instance_has_slot(aTHX_ instance, slot);
OUTPUT:
    RETVAL

SV*
get_slot_value(SV* self, SV* instance, SV* slot)
CODE:
    PERL_UNUSED_VAR(self);
    RETVAL = mop_instance_get_slot(aTHX_ instance, slot);
    RETVAL = RETVAL ? newSVsv(RETVAL) : &PL_sv_undef;
OUTPUT:
    RETVAL

SV*
set_slot_value(SV* self, SV* instance, SV* slot, SV* value)
CODE:
    PERL_UNUSED_VAR(self);
    RETVAL = mop_instance_set_slot(aTHX_ instance, slot, value);
    SvREFCNT_inc_simple_void_NN(RETVAL);
OUTPUT:
    RETVAL

SV*
deinitialize_slot(SV* self, SV* instance, SV* slot)
CODE:
    PERL_UNUSED_VAR(self);
    RETVAL = mop_instance_delete_slot(aTHX_ instance, slot);
    if(RETVAL){
        SvREFCNT_inc_simple_void_NN(RETVAL);
    }
    else{
        RETVAL = &PL_sv_undef;
    }
OUTPUT:
    RETVAL

void
weaken_slot_value(SV* self, SV* instance, SV* slot)
CODE:
    PERL_UNUSED_VAR(self);
    mop_instance_weaken_slot(aTHX_ instance, slot);
