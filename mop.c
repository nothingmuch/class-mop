#define NEED_newRV_noinc_GLOBAL
#define NEED_sv_2pv_flags_GLOBAL
#define NEED_sv_2pv_nolen_GLOBAL
#define NEED_newSVpvn_flags_GLOBAL
#include "mop.h"

void
mop_call_xs (pTHX_ XSPROTO(subaddr), CV *cv, SV **mark)
{
    dSP;
    PUSHMARK(mark);
    (*subaddr)(aTHX_ cv);
    PUTBACK;
}

#if PERL_BCDVERSION >= 0x5010000
UV
mop_check_package_cache_flag (pTHX_ HV *stash)
{
    assert(SvTYPE(stash) == SVt_PVHV);

    /* here we're trying to implement a c version of mro::get_pkg_gen($stash),
     * however the perl core doesn't make it easy for us. It doesn't provide an
     * api that just does what we want.
     *
     * However, we know that the information we want is, inside the core,
     * available using HvMROMETA(stash)->pkg_gen. Unfortunately, although the
     * HvMROMETA macro is public, it is implemented using Perl_mro_meta_init,
     * which is not public and only available inside the core, as the mro
     * interface as well as the structure returned by mro_meta_init isn't
     * considered to be stable yet.
     *
     * Perl_mro_meta_init isn't declared static, so we could just define it
     * ourselfs if perls headers don't do that for us, except that won't work
     * on platforms where symbols need to be explicitly exported when linking
     * shared libraries.
     *
     * So our, hopefully temporary, solution is to be even more evil and
     * basically reimplement HvMROMETA in a very fragile way that'll blow up
     * when the relevant parts of the mro implementation in core change.
     *
     * :-(
     *
     */

    return HvAUX(stash)->xhv_mro_meta
         ? HvAUX(stash)->xhv_mro_meta->pkg_gen
         : 0;
}

#else /* pre 5.10.0 */

UV
mop_check_package_cache_flag (pTHX_ HV *stash)
{
    PERL_UNUSED_ARG(stash);
    assert(SvTYPE(stash) == SVt_PVHV);

    return PL_sub_generation;
}
#endif

SV *
mop_call0 (pTHX_ SV *const self, SV *const method)
{
    dSP;
    SV *ret;

    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(method, G_SCALAR | G_METHOD);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return ret;
}

SV *
mop_call1 (pTHX_ SV *const self, SV *const method, SV* const arg1)
{
    dSP;
    SV *ret;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(self);
    PUSHs(arg1);
    PUTBACK;

    call_sv(method, G_SCALAR | G_METHOD);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return ret;
}


int
mop_get_code_info (SV *coderef, char **pkg, char **name)
{
    if (!SvOK(coderef) || !SvROK(coderef) || SvTYPE(SvRV(coderef)) != SVt_PVCV) {
        return 0;
    }

    coderef = SvRV(coderef);

    /* sub is still being compiled */
    if (!CvGV(coderef)) {
        return 0;
    }

    /* I think this only gets triggered with a mangled coderef, but if
       we hit it without the guard, we segfault. The slightly odd return
       value strikes me as an improvement (mst)
    */

    if ( isGV_with_GP(CvGV(coderef)) ) {
        GV *gv   = CvGV(coderef);
        *pkg     = HvNAME( GvSTASH(gv) ? GvSTASH(gv) : CvSTASH(coderef) );
        *name    = GvNAME( CvGV(coderef) );
    } else {
        *pkg     = "__UNKNOWN__";
        *name    = "__ANON__";
    }

    return 1;
}

void
mop_get_package_symbols (HV *stash, type_filter_t filter, get_package_symbols_cb_t cb, void *ud)
{
    dTHX;
    HE *he;

    (void)hv_iterinit(stash);

    if (filter == TYPE_FILTER_NONE) {
        while ( (he = hv_iternext(stash)) ) {
            STRLEN keylen;
            const char *key = HePV(he, keylen);
            if (!cb(key, keylen, HeVAL(he), ud)) {
                return;
            }
        }
        return;
    }

    while ( (he = hv_iternext(stash)) ) {
        SV *const gv = HeVAL(he);
        SV *sv = NULL;
        char *key;
        STRLEN keylen;
        char *package;

        switch( SvTYPE(gv) ) {
#ifndef SVt_RV
            case SVt_RV:
#endif
            case SVt_PV:
            case SVt_IV:
                /* expand the gv into a real typeglob if it
                 * contains stub functions and we were asked to
                 * return CODE symbols */
                if (filter == TYPE_FILTER_CODE) {
                    if (SvROK(gv)) {
                        SV* fq;
                        /* we don't really care about the length,
                           but that's the API */
                        key = HePV(he, keylen);
                        package = HvNAME(stash);
                        fq = sv_2mortal(newSVpvf("%s::%s", package, key));
                        sv = (SV *)get_cv(SvPV_nolen(fq), 0);
                        break;
                    }

                    key = HePV(he, keylen);
                    gv_init((GV *)gv, stash, key, keylen, GV_ADDMULTI);
                }
                /* fall through */
            case SVt_PVGV:
                switch (filter) {
                    case TYPE_FILTER_CODE:   sv = (SV *)GvCVu(gv); break;
                    case TYPE_FILTER_ARRAY:  sv = (SV *)GvAV(gv);  break;
                    case TYPE_FILTER_IO:     sv = (SV *)GvIO(gv);  break;
                    case TYPE_FILTER_HASH:   sv = (SV *)GvHV(gv);  break;
                    case TYPE_FILTER_SCALAR: sv = (SV *)GvSV(gv);  break;
                    default:
                        croak("Unknown type");
                }
                break;
            default:
                continue;
        }

        if (sv) {
            const char *key = HePV(he, keylen);
            if (!cb(key, keylen, sv, ud)) {
                return;
            }
        }
    }
}

static bool
collect_all_symbols (const char *key, STRLEN keylen, SV *val, void *ud)
{
    dTHX;
    HV *hash = (HV *)ud;

    if (!hv_store (hash, key, keylen, newRV_inc(val), 0)) {
        croak("failed to store symbol ref");
    }

    return TRUE;
}

HV *
mop_get_all_package_symbols (HV *stash, type_filter_t filter)
{
    dTHX;
    HV *ret = newHV ();
    mop_get_package_symbols (stash, filter, collect_all_symbols, ret);
    return ret;
}


MAGIC*
mop_mg_find(pTHX_ SV* const sv, const MGVTBL* const vtbl, I32 const flags){
    MAGIC* mg;

    assert(sv != NULL);
    for(mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic){
        if(mg->mg_virtual == vtbl){
            return mg;
        }
    }

    if(flags & MOPf_DIE_ON_FAIL){
        croak("mop_mg_find: no MAGIC found for %"SVf, sv_2mortal(newRV_inc(sv)));
    }
    return NULL;
}
