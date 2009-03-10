#include "mop.h"

static bool
find_method (const char *key, STRLEN keylen, SV *val, void *ud)
{
    bool *found_method = (bool *)ud;
    *found_method = TRUE;
    return FALSE;
}

DECLARE_KEY(name);
DECLARE_KEY(package);
DECLARE_KEY(package_name);
DECLARE_KEY(body);
DECLARE_KEY(package_cache_flag);
DECLARE_KEY(methods);
DECLARE_KEY(VERSION);
DECLARE_KEY(ISA);

SV *method_metaclass;
SV *associated_metaclass;
SV *wrap;

MODULE = Class::MOP   PACKAGE = Class::MOP

PROTOTYPES: DISABLE

BOOT:
    PREHASH_KEY(name);
    PREHASH_KEY(body);
    PREHASH_KEY(package);
    PREHASH_KEY(package_name);
    PREHASH_KEY(methods);
    PREHASH_KEY(ISA);
    PREHASH_KEY(VERSION);
    PREHASH_KEY_WITH_VALUE(package_cache_flag, "_package_cache_flag");

    method_metaclass     = newSVpvs("method_metaclass");
    wrap                 = newSVpvs("wrap");
    associated_metaclass = newSVpvs("associated_metaclass");

	MOP_CALL_BOOT (boot_Class__MOP__Package);
	MOP_CALL_BOOT (boot_Class__MOP__Class);
	MOP_CALL_BOOT (boot_Class__MOP__Attribute);
	MOP_CALL_BOOT (boot_Class__MOP__Method);

# use prototype here to be compatible with get_code_info from Sub::Identify
void
get_code_info(coderef)
    SV *coderef
    PROTOTYPE: $
    PREINIT:
        char *pkg  = NULL;
        char *name = NULL;
    PPCODE:
        if (get_code_info(coderef, &pkg, &name)) {
            EXTEND(SP, 2);
            PUSHs(newSVpv(pkg, 0));
            PUSHs(newSVpv(name, 0));
        }

# This is some pretty grotty logic. It _should_ be parallel to the
# pure Perl version in lib/Class/MOP.pm, so if you want to understand
# it we suggest you start there.
void
is_class_loaded(klass=&PL_sv_undef)
    SV *klass
    PREINIT:
        HV *stash;
        bool found_method = FALSE;
    PPCODE:
        if (!SvPOK(klass) || !SvCUR(klass)) {
            XSRETURN_NO;
        }

        stash = gv_stashsv(klass, 0);
        if (!stash) {
            XSRETURN_NO;
        }

        if (hv_exists_ent (stash, key_VERSION, hash_VERSION)) {
            HE *version = hv_fetch_ent(stash, key_VERSION, 0, hash_VERSION);
            SV *version_sv;
            if (version && HeVAL(version) && (version_sv = GvSV(HeVAL(version)))) {
                if (SvROK(version_sv)) {
                    SV *version_sv_ref = SvRV(version_sv);

                    if (SvOK(version_sv_ref)) {
                        XSRETURN_YES;
                    }
                }
                else if (SvOK(version_sv)) {
                    XSRETURN_YES;
                }
            }
        }

        if (hv_exists_ent (stash, key_ISA, hash_ISA)) {
            HE *isa = hv_fetch_ent(stash, key_ISA, 0, hash_ISA);
            if (isa && HeVAL(isa) && GvAV(HeVAL(isa))) {
                XSRETURN_YES;
            }
        }

        get_package_symbols(stash, TYPE_FILTER_CODE, find_method, &found_method);
        if (found_method) {
            XSRETURN_YES;
        }

        XSRETURN_NO;
