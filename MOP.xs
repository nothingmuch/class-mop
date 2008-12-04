/* There's a lot of cases of doubled parens in here like this:

  while ( (he = ...) ) {

This shuts up warnings from gcc -Wall
*/

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_sv_2pv_flags
#define NEED_sv_2pv_nolen
#include "ppport.h"

SV *key_name;
U32 hash_name;

SV *key_package;
U32 hash_package;

SV *key_package_name;
U32 hash_package_name;

SV *key_body;
U32 hash_body;

SV* method_metaclass;
SV* associated_metaclass;
SV* wrap;


#define check_package_cache_flag(stash) mop_check_package_cache_flag(aTHX_ stash)
#ifdef HvMROMETA /* 5.10.0 */

#ifndef mro_meta_init
#define mro_meta_init(stash) Perl_mro_meta_init(aTHX_ stash) /* used in HvMROMETA macro */
#endif /* !mro_meta_init */

static UV
mop_check_package_cache_flag(pTHX_ HV* stash) {
    assert(SvTYPE(stash) == SVt_PVHV);

    return HvMROMETA(stash)->pkg_gen; /* mro::get_pkg_gen($pkg) */
}

#else /* pre 5.10.0 */

static UV
mop_check_package_cache_flag(pTHX_ HV* stash) {
    PERL_UNUSED_ARG(stash);
    assert(SvTYPE(stash) == SVt_PVHV);

    return PL_sub_generation;
}
#endif

#define call0(s, m)  mop_call0(aTHX_ s, m)
static SV*
mop_call0(pTHX_ SV* const self, SV* const method) {
    dSP;
    SV* ret;

    PUSHMARK(SP);
    XPUSHs(self);
    PUTBACK;

    call_sv(method, G_SCALAR | G_METHOD);

    SPAGAIN;
    ret = POPs;
    PUTBACK;

    return ret;
}

static void
mop_update_method_map(pTHX_ SV* const self, SV* const class_name, HV* const stash, HV* const map) {
    const char* const class_name_pv = HvNAME(stash); /* must be HvNAME(stash), not SvPV_nolen_const(class_name) */
    SV*   method_metaclass_name;
    char* method_name;
    I32   method_name_len;
    GV* gv;
    dSP;

    /* this function massivly overlaps with the xs version of
     * get_all_package_symbols. a common c function to walk the symbol table
     * should be factored out and used by both.  --rafl */

    hv_iterinit(stash);
    while ( (gv = (GV*)hv_iternextsv(stash, &method_name, &method_name_len)) ) {
        CV* cv;
        switch (SvTYPE (gv)) {
#ifndef SVt_RV
            case SVt_RV:
#endif
            case SVt_IV:
            case SVt_PV:
                /* rafl says that this wastes memory savings that GvSVs have
                   in 5.8.9 and 5.10.x. But without it some tests fail. rafl
                   says the right thing to do is to handle GvSVs differently
                   here. */
                gv_init((GV*)gv, stash, method_name, method_name_len, GV_ADDMULTI);
                /* fall through */
            default:
                break;
        }

        if ( SvTYPE(gv) == SVt_PVGV && (cv = GvCVu(gv)) ) {
            GV* const cvgv = CvGV(cv);
            /* ($cvpkg_name, $cv_name) = get_code_info($cv) */
            const char* const cvpkg_name = HvNAME(GvSTASH(cvgv));
            const char* const cv_name    = GvNAME(cvgv);
            SV* method_slot;
            SV* method_object;

            /* this checks to see that the subroutine is actually from our package  */
            if ( !(strEQ(cvpkg_name, "constant") && strEQ(cv_name, "__ANON__")) ) {
                if ( strNE(cvpkg_name, class_name_pv) ) {
                    continue;
                }
            }

            method_slot = *hv_fetch(map, method_name, method_name_len, TRUE);
            if ( SvOK(method_slot) ) {
                SV* const body = call0(method_slot, key_body); /* $method_object->body() */
                if ( SvROK(body) && ((CV*) SvRV(body)) == cv ) {
                    continue;
                }
            }

            method_metaclass_name = call0(self, method_metaclass); /* $self->method_metaclass() */

            /*
                $method_object = $method_metaclass->wrap(
                    $cv,
                    associated_metaclass => $self,
                    package_name         => $class_name,
                    name                 => $method_name
                );
            */
            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            EXTEND(SP, 8);
            PUSHs(method_metaclass_name); /* invocant */
            mPUSHs(newRV_inc((SV*)cv));
            PUSHs(associated_metaclass);
            PUSHs(self);
            PUSHs(key_package_name);
            PUSHs(class_name);
            PUSHs(key_name);
            mPUSHs(newSVpv(method_name, method_name_len));
            PUTBACK;

            call_sv(wrap, G_SCALAR | G_METHOD);
            SPAGAIN;
            method_object = POPs;
            PUTBACK;
            /* $map->{$method_name} = $method_object */
            sv_setsv(method_slot, method_object);

            FREETMPS;
            LEAVE;
        }
    }
}


/*
get_code_info:
  Pass in a coderef, returns:
  [ $pkg_name, $coderef_name ] ie:
  [ 'Foo::Bar', 'new' ]
*/

MODULE = Class::MOP   PACKAGE = Class::MOP

BOOT:
    key_name = newSVpvs("name");
    key_body = newSVpvs("body");
    key_package = newSVpvs("package");
    key_package_name = newSVpvs("package_name");

    PERL_HASH(hash_name, "name", 4);
    PERL_HASH(hash_body, "body", 4);
    PERL_HASH(hash_package, "package", 7);
    PERL_HASH(hash_package_name, "package_name", 12);

    method_metaclass     = newSVpvs("method_metaclass");
    wrap                 = newSVpvs("wrap");
    associated_metaclass = newSVpvs("associated_metaclass");


PROTOTYPES: ENABLE


void
get_code_info(coderef)
  SV* coderef
  PREINIT:
    char* name;
    char* pkg;
  PPCODE:
    if ( SvOK(coderef) && SvROK(coderef) && SvTYPE(SvRV(coderef)) == SVt_PVCV ) {
      coderef = SvRV(coderef);
      /* I think this only gets triggered with a mangled coderef, but if
         we hit it without the guard, we segfault. The slightly odd return
         value strikes me as an improvement (mst)
      */
#ifdef isGV_with_GP
      if ( isGV_with_GP(CvGV(coderef)) ) {
#endif
        pkg     = HvNAME( GvSTASH(CvGV(coderef)) );
        name    = GvNAME( CvGV(coderef) );
#ifdef isGV_with_GP
      } else {
        pkg     = "__UNKNOWN__";
        name    = "__ANON__";
      }
#endif

      EXTEND(SP, 2);
      PUSHs(newSVpvn(pkg, strlen(pkg)));
      PUSHs(newSVpvn(name, strlen(name)));
    }


MODULE = Class::MOP   PACKAGE = Class::MOP::Package

void
get_all_package_symbols(self, ...)
    SV *self
    PROTOTYPE: $;$
    PREINIT:
        HV *stash = NULL;
        SV *type_filter = NULL;
        register HE *he;
    PPCODE:
        if ( ! SvROK(self) ) {
            die("Cannot call get_all_package_symbols as a class method");
        }

        switch (GIMME_V) {
            case G_VOID: return; break;
            case G_SCALAR: ST(0) = &PL_sv_undef; return; break;
        }

        if ( items > 1 ) type_filter = ST(1);

        PUTBACK;

        if ( (he = hv_fetch_ent((HV *)SvRV(self), key_package, 0, hash_package)) )
            stash = gv_stashsv(HeVAL(he),0);

        if (stash) {

            (void)hv_iterinit(stash);

            if ( type_filter && SvPOK(type_filter) ) {
                const char *const type = SvPV_nolen(type_filter);

                while ( (he = hv_iternext(stash)) ) {
                    SV *const gv = HeVAL(he);
                    SV *sv = NULL;
                    char *key;
                    STRLEN keylen;
                    char *package;
                    SV *fq;

                    switch( SvTYPE(gv) ) {
#ifndef SVt_RV
                        case SVt_RV:
#endif
                        case SVt_PV:
                        case SVt_IV:
                            /* expand the gv into a real typeglob if it
                             * contains stub functions and we were asked to
                             * return CODE symbols */
                            if (*type == 'C') {
                                if (SvROK(gv)) {
                                    /* we don't really care about the length,
                                       but that's the API */
                                    key = HePV(he, keylen);
                                    package = HvNAME(stash);
                                    fq = newSVpvf("%s::%s", package, key);
                                    sv = (SV*)get_cv(SvPV_nolen(fq), 0);
                                    break;
                                }

                                key = HePV(he, keylen);
                                gv_init((GV *)gv, stash, key, keylen, GV_ADDMULTI);
                            }
                            /* fall through */
                        case SVt_PVGV:
                            switch (*type) {
                                case 'C': sv = (SV *)GvCVu(gv); break; /* CODE */
                                case 'A': sv = (SV *)GvAV(gv); break; /* ARRAY */
                                case 'I': sv = (SV *)GvIO(gv); break; /* IO */
                                case 'H': sv = (SV *)GvHV(gv); break; /* HASH */
                                case 'S': sv = (SV *)GvSV(gv); break; /* SCALAR */
                                default:
                                          croak("Unknown type %s\n", type);
                            }
                            break;
                        default:
                            continue;
                    }

                    if (sv) {
                        SV *key = hv_iterkeysv(he);
                        SPAGAIN;
                        EXTEND(SP, 2);
                        PUSHs(key);
                        PUSHs(sv_2mortal(newRV_inc(sv)));
                        PUTBACK;
                    }
                }
            } else {
                EXTEND(SP, HvKEYS(stash) * 2);

                while ( (he = hv_iternext(stash)) ) {
                    SV *key = hv_iterkeysv(he);
                    SV *sv = HeVAL(he);
                    SPAGAIN;
                    PUSHs(key);
                    PUSHs(sv);
                    PUTBACK;
                }
            }

        }

void
name(self)
    SV *self
    PREINIT:
        register HE *he;
    PPCODE:
        if ( ! SvROK(self) ) {
            die("Cannot call name as a class method");
        }

        if ( (he = hv_fetch_ent((HV *)SvRV(self), key_package, 0, hash_package)) )
            XPUSHs(HeVAL(he));
        else
            ST(0) = &PL_sv_undef;

MODULE = Class::MOP   PACKAGE = Class::MOP::Attribute

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

MODULE = Class::MOP   PACKAGE = Class::MOP::Method

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


MODULE = Class::MOP    PACKAGE = Class::MOP::Class

void
get_method_map(self)
    SV* self
    PREINIT:
        SV* const class_name = HeVAL( hv_fetch_ent((HV*)SvRV(self), key_package, TRUE, hash_package) );
        HV* const stash      = gv_stashsv(class_name, TRUE);
        UV  const current    = check_package_cache_flag(stash);
        SV* const cache_flag = *hv_fetchs((HV*)SvRV(self), "_package_cache_flag", TRUE);
        SV* const map_ref    = *hv_fetchs((HV*)SvRV(self), "methods", TRUE);
    PPCODE:
        if ( ! SvRV(self) ) {
            die("Cannot call get_method_map as a class method");
        }

        /* in  $self->{methods} does not yet exist (or got deleted) */
        if ( ! (SvROK(map_ref) && SvTYPE(SvRV(map_ref)) == SVt_PVHV) ) {
            SV* new_map_ref = newRV_noinc((SV*)newHV());
            sv_2mortal(new_map_ref);
            sv_setsv(map_ref, new_map_ref);
        }

        if ( ! (SvOK(cache_flag) && SvUV(cache_flag) == current) ) {
            ENTER;
            SAVETMPS;

            mop_update_method_map(aTHX_ self, class_name, stash, (HV*)SvRV(map_ref));
            sv_setuv(cache_flag, check_package_cache_flag(stash)); /* update_cache_flag() */

            FREETMPS;
            LEAVE;
        }

        XPUSHs(map_ref);

