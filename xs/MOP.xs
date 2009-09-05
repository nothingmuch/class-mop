#include "mop.h"

SV *mop_method_metaclass;
SV *mop_associated_metaclass;
SV *mop_associated_attribute;
SV *mop_wrap;
SV *mop_methods;
SV *mop_name;
SV *mop_body;
SV *mop_package;
SV *mop_package_name;
SV *mop_package_cache_flag;
SV *mop_initialize;
SV *mop_isa;
SV *mop_can;
SV *mop_Class;
SV *mop_VERSION;
SV *mop_ISA;

/* equivalent to "blessed($x) && $x->isa($klass)" */
bool
mop_is_instance_of(pTHX_ SV* const sv, SV* const klass){
    assert(sv);
    assert(klass);

    if(SvROK(sv) && SvOBJECT(SvRV(sv)) && SvOK(klass)){
        bool ok;

        ENTER;
        SAVETMPS;

        ok = SvTRUEx(mop_call1(aTHX_ sv, mop_isa, klass));

        FREETMPS;
        LEAVE;

        return ok;
    }

    return FALSE;
}

static bool
find_method (const char *key, STRLEN keylen, SV *val, void *ud)
{
    bool * const found_method = (bool *)ud;
    PERL_UNUSED_ARG(key);
    PERL_UNUSED_ARG(keylen);
    PERL_UNUSED_ARG(val);
    *found_method = TRUE;
    return FALSE;
}


bool
mop_is_class_loaded(pTHX_ SV * const klass){
    HV *stash;
    HE* he;

    if (!(SvPOKp(klass) && SvCUR(klass))) { /* XXX: SvPOK does not work with magical scalars */
        return FALSE;
    }

    stash = gv_stashsv(klass, 0);
    if (!stash) {
        return FALSE;
    }

    if (( he = hv_fetch_ent (stash, mop_VERSION, FALSE, 0U) )) {
        GV* const version_gv = (GV*)HeVAL(he);
        if(isGV(version_gv) && GvSV(version_gv) && SvOK(GvSV(version_gv))){
            return TRUE;
        }
    }

    if (( he = hv_fetch_ent (stash, mop_ISA, FALSE, 0U) )) {
        GV* const isa_gv = (GV*)HeVAL(he);
        if(isGV(isa_gv) && GvAV(isa_gv) && av_len(GvAV(isa_gv)) != -1){
            return TRUE;
        }
    }

    {
        bool found_method = FALSE;
        mop_get_package_symbols(stash, TYPE_FILTER_CODE, find_method, &found_method);
        return found_method;
    }
}

MODULE = Class::MOP   PACKAGE = Class::MOP

PROTOTYPES: DISABLE

BOOT:
    mop_method_metaclass     = MAKE_KEYSV(method_metaclass);
    mop_associated_metaclass = MAKE_KEYSV(associated_metaclass);
    mop_associated_attribute = MAKE_KEYSV(associated_attribute);
    mop_wrap                 = MAKE_KEYSV(wrap);
    mop_methods              = MAKE_KEYSV(methods);
    mop_name                 = MAKE_KEYSV(name);
    mop_body                 = MAKE_KEYSV(body);
    mop_package              = MAKE_KEYSV(package);
    mop_package_name         = MAKE_KEYSV(package_name);
    mop_package_cache_flag   = MAKE_KEYSV(_package_cache_flag);
    mop_initialize           = MAKE_KEYSV(initialize);
    mop_Class                = MAKE_KEYSV(Class::MOP::Class);
    mop_VERSION              = MAKE_KEYSV(VERSION);
    mop_ISA                  = MAKE_KEYSV(ISA);
    mop_isa                  = MAKE_KEYSV(isa);
    mop_can                  = MAKE_KEYSV(can);

    MOP_CALL_BOOT( Class__MOP__Package );
    MOP_CALL_BOOT( Class__MOP__Class );
    MOP_CALL_BOOT( Class__MOP__Attribute );
    MOP_CALL_BOOT( Class__MOP__Instance );
    MOP_CALL_BOOT( Class__MOP__Method );
    MOP_CALL_BOOT( Class__MOP__Method__Accessor );
    MOP_CALL_BOOT( Class__MOP__Method__Constructor );

# use prototype here to be compatible with get_code_info from Sub::Identify
void
get_code_info(coderef)
    SV *coderef
    PROTOTYPE: $
    PREINIT:
        char *pkg  = NULL;
        char *name = NULL;
    PPCODE:
        SvGETMAGIC(coderef);
        if (mop_get_code_info(coderef, &pkg, &name)) {
            EXTEND(SP, 2);
            mPUSHs(newSVpv(pkg, 0));
            mPUSHs(newSVpv(name, 0));
        }


bool
is_class_loaded(SV* klass = &PL_sv_undef)
INIT:
    SvGETMAGIC(klass);



#bool
#is_instance_of(SV* sv, SV* klass)
#INIT:
#    SvGETMAGIC(sv);
#    SvGETMAGIC(klass);
#
