#include "mop.h"

SV *mop_method_metaclass;
SV *mop_associated_metaclass;
SV *mop_wrap;
SV *mop_methods;
SV *mop_name;
SV *mop_body;
SV *mop_package;
SV *mop_package_name;
SV *mop_package_cache_flag;

SV *mop_VERSION;
SV *mop_ISA;
SV *mop_isa;

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

    if (!(SvPOKp(klass) && SvCUR(klass))) { /* XXX: SvPOK does not work with magical scalars */
        return FALSE;
    }

    stash = gv_stashsv(klass, 0);
    if (!stash) {
        return FALSE;
    }

    if (hv_exists_ent (stash, mop_VERSION, 0U)) {
        HE *version = hv_fetch_ent(stash, mop_VERSION, 0, 0U);
        SV *version_sv;
        if (version && HeVAL(version) && (version_sv = GvSV(HeVAL(version)))) {
            if (SvROK(version_sv)) {
                SV *version_sv_ref = SvRV(version_sv);

                if (SvOK(version_sv_ref)) {
                    return TRUE;
                }
            }
            else if (SvOK(version_sv)) {
                return TRUE;
            }
        }
    }

    if (hv_exists_ent (stash, mop_ISA, 0U)) {
        HE *isa = hv_fetch_ent(stash, mop_ISA, 0, 0U);
        if (isa && HeVAL(isa) && GvAV(HeVAL(isa)) && av_len(GvAV(HeVAL(isa))) != -1) {
            return TRUE;;
        }
    }

    {
        bool found_method = FALSE;
        mop_get_package_symbols(stash, TYPE_FILTER_CODE, find_method, &found_method);
       return found_method;
    }
}

EXTERN_C XS(boot_Class__MOP__Package);
EXTERN_C XS(boot_Class__MOP__Attribute);
EXTERN_C XS(boot_Class__MOP__Method);
EXTERN_C XS(boot_Class__MOP__Instance);
EXTERN_C XS(boot_Class__MOP__Method__Accessor);

MODULE = Class::MOP   PACKAGE = Class::MOP

PROTOTYPES: DISABLE

BOOT:
    mop_method_metaclass     = MAKE_KEYSV(method_metaclass);
    mop_wrap                 = MAKE_KEYSV(wrap);
    mop_associated_metaclass = MAKE_KEYSV(associated_metaclass);
    mop_methods              = MAKE_KEYSV(methods);
    mop_name                 = MAKE_KEYSV(name);
    mop_body                 = MAKE_KEYSV(body);
    mop_package              = MAKE_KEYSV(package);
    mop_package_name         = MAKE_KEYSV(package_name);
    mop_package_cache_flag   = MAKE_KEYSV(_package_cache_flag);
    mop_VERSION              = MAKE_KEYSV(VERSION);
    mop_ISA                  = MAKE_KEYSV(ISA);
    mop_isa                  = MAKE_KEYSV(isa);

    MOP_CALL_BOOT (boot_Class__MOP__Package);
    MOP_CALL_BOOT (boot_Class__MOP__Attribute);
    MOP_CALL_BOOT (boot_Class__MOP__Method);
    MOP_CALL_BOOT (boot_Class__MOP__Instance);
    MOP_CALL_BOOT (boot_Class__MOP__Method__Accessor);

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
