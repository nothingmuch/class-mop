
#include "mop.h"

static void
mop_deconstruct_variable_name(pTHX_ SV* const variable,
    const char** const var_name, STRLEN* const var_name_len,
    svtype* const type,
    const char** const type_name) {


    if(SvROK(variable) && SvTYPE(SvRV(variable)) == SVt_PVHV){
        /* e.g. variable = { type => "SCALAR", name => "foo" } */
        HV* const hv = (HV*)SvRV(variable);
        SV** svp;
        STRLEN len;
        const char* pv;

        svp = hv_fetchs(hv, "name", FALSE);
        if(!(svp && SvOK(*svp))){
            croak("You must pass a variable name");
        }
        *var_name     = SvPV_const(*svp, len);
        *var_name_len = len;
        if(len < 1){
            croak("You must pass a variable name");
        }

        svp = hv_fetchs(hv, "type", FALSE);
        if(!(svp && SvOK(*svp))) {
            croak("You must pass a variable type");
        }
        pv = SvPV_nolen_const(*svp);
        if(strEQ(pv, "SCALAR")){
            *type = SVt_PV; /* for all the type of scalars */
        }
        else if(strEQ(pv, "ARRAY")){
            *type = SVt_PVAV;
        }
        else if(strEQ(pv, "HASH")){
            *type = SVt_PVHV;
        }
        else if(strEQ(pv, "CODE")){
            *type = SVt_PVCV;
        }
        else if(strEQ(pv, "GLOB")){
            *type = SVt_PVGV;
        }
        else if(strEQ(pv, "IO")){
            *type = SVt_PVIO;
        }
        else{
            croak("I do not recognize that type '%s'", pv);
        }
        *type_name = pv;
    }
    else {
        STRLEN len;
        const char* pv;
        /* e.g. variable = '$foo' */
        if(!SvOK(variable)) {
            croak("You must pass a variable name");
        }
        pv = SvPV_const(variable, len);
        if(len < 2){
            croak("You must pass a variable name including a sigil");
        }

        *var_name     = pv  + 1;
        *var_name_len = len - 1;

        switch(pv[0]){
        case '$':
            *type      = SVt_PV; /* for all the types of scalars */
            *type_name = "SCALAR";
            break;
        case '@':
            *type      = SVt_PVAV;
            *type_name = "ARRAY";
            break;
        case '%':
            *type      = SVt_PVHV;
            *type_name = "HASH";
            break;
        case '&':
            *type      = SVt_PVCV;
            *type_name = "CODE";
            break;
        case '*':
            *type      = SVt_PVGV;
            *type_name = "GLOB";
            break;
        default:
            croak("I do not recognize that sigil '%c'", pv[0]);
        }
    }
}

static GV*
mop_get_gv(pTHX_ SV* const self, svtype const type, const char* const var_name, I32 const var_name_len, I32 const flags){
    SV* package_name;

    if(!(flags & ~GV_NOADD_MASK)){ /* for shortcut fetching */
        SV* const ns = mop_call0(aTHX_ self, mop_namespace);
        GV** gvp;
        if(!(SvROK(ns) && SvTYPE(SvRV(ns)) == SVt_PVHV)){
            croak("namespace() did not return a hash reference");
        }
        gvp = (GV**)hv_fetch((HV*)SvRV(ns), var_name, var_name_len, FALSE);
        if(gvp && isGV_with_GP(*gvp)){
            return *gvp;
        }
    }

    package_name = mop_call0(aTHX_ self, KEY_FOR(name));

    if(!SvOK(package_name)){
        croak("name() did not return a defined value");
    }

    return gv_fetchpv(Perl_form(aTHX_ "%"SVf"::%s", package_name, var_name), flags, type);
}

static SV*
mop_gv_elem(pTHX_ GV* const gv, svtype const type, I32 const add){
    SV* sv;

    if(!gv){
        return NULL;
    }

    assert(isGV_with_GP(gv));

    switch(type){
    case SVt_PVAV:
        sv = (SV*)(add ? GvAVn(gv) : GvAV(gv));
        break;
    case SVt_PVHV:
        sv = (SV*)(add ? GvHVn(gv) : GvHV(gv));
        break;
    case SVt_PVCV:
        sv = (SV*)GvCV(gv);
        break;
    case SVt_PVIO:
        sv = (SV*)(add ? GvIOn(gv) : GvIO(gv));
        break;
    case SVt_PVGV:
        sv = (SV*)gv;
        break;
    default: /* SCALAR */
        sv =       add ? GvSVn(gv) : GvSV(gv);
        break;
    }

    return sv;
}


static void
mop_update_method_map(pTHX_ SV *const self, SV *const class_name, HV *const stash, HV *const map)
{
    const char *const class_name_pv = HvNAME(stash); /* must be HvNAME(stash), not SvPV_nolen_const(class_name) */
    SV   *method_metaclass_name;
    char *method_name;
    I32   method_name_len;
    SV   *coderef;
    HV   *symbols;
    dSP;

    symbols = mop_get_all_package_symbols(stash, TYPE_FILTER_CODE);
    sv_2mortal((SV*)symbols);
    (void)hv_iterinit(symbols);
    while ( (coderef = hv_iternextsv(symbols, &method_name, &method_name_len)) ) {
        CV *cv = (CV *)SvRV(coderef);
        char *cvpkg_name;
        char *cv_name;
        SV *method_slot;
        SV *method_object;

        if (!mop_get_code_info(coderef, &cvpkg_name, &cv_name)) {
            continue;
        }

        /* this checks to see that the subroutine is actually from our package  */
        if ( !(strEQ(cvpkg_name, "constant") && strEQ(cv_name, "__ANON__")) ) {
            if ( strNE(cvpkg_name, class_name_pv) ) {
                continue;
            }
        }

        method_slot = *hv_fetch(map, method_name, method_name_len, TRUE);
        if ( SvOK(method_slot) ) {
            SV *const body = mop_call0(aTHX_ method_slot, KEY_FOR(body)); /* $method_object->body() */
            if ( SvROK(body) && ((CV *) SvRV(body)) == cv ) {
                continue;
            }
        }

        method_metaclass_name = mop_call0(aTHX_ self, mop_method_metaclass); /* $self->method_metaclass() */

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
        mPUSHs(newRV_inc((SV *)cv));
        PUSHs(mop_associated_metaclass);
        PUSHs(self);
        PUSHs(KEY_FOR(package_name));
        PUSHs(class_name);
        PUSHs(KEY_FOR(name));
        mPUSHs(newSVpv(method_name, method_name_len));
        PUTBACK;

        call_sv(mop_wrap, G_SCALAR | G_METHOD);
        SPAGAIN;
        method_object = POPs;
        PUTBACK;
        /* $map->{$method_name} = $method_object */
        sv_setsv(method_slot, method_object);

        FREETMPS;
        LEAVE;
    }
}

MODULE = Class::MOP::Package   PACKAGE = Class::MOP::Package

PROTOTYPES: DISABLE

void
get_all_package_symbols(self, filter=TYPE_FILTER_NONE)
    SV *self
    type_filter_t filter
    PREINIT:
        HV *stash = NULL;
        HV *symbols = NULL;
        register HE *he;
    PPCODE:
        if ( ! SvROK(self) ) {
            die("Cannot call get_all_package_symbols as a class method");
        }

        if (GIMME_V == G_VOID) {
            XSRETURN_EMPTY;
        }

        PUTBACK;

        if ( (he = hv_fetch_ent((HV *)SvRV(self), KEY_FOR(package), 0, HASH_FOR(package))) ) {
            stash = gv_stashsv(HeVAL(he), 0);
        }


        if (!stash) {
            XSRETURN_UNDEF;
        }

        symbols = mop_get_all_package_symbols(stash, filter);
        PUSHs(sv_2mortal(newRV_noinc((SV *)symbols)));

void
get_method_map(self)
    SV *self
    PREINIT:
        HV *const obj        = (HV *)SvRV(self);
        SV *const class_name = HeVAL( hv_fetch_ent(obj, KEY_FOR(package), 0, HASH_FOR(package)) );
        HV *const stash      = gv_stashsv(class_name, 0);
        UV current;
        SV *cache_flag;
        SV *map_ref;
    PPCODE:
        if (!stash) {
             mXPUSHs(newRV_noinc((SV *)newHV()));
             return;
        }

        current    = mop_check_package_cache_flag(aTHX_ stash);
        cache_flag = HeVAL( hv_fetch_ent(obj, KEY_FOR(package_cache_flag), TRUE, HASH_FOR(package_cache_flag)));
        map_ref    = HeVAL( hv_fetch_ent(obj, KEY_FOR(methods), TRUE, HASH_FOR(methods)));

        /* $self->{methods} does not yet exist (or got deleted) */
        if ( !SvROK(map_ref) || SvTYPE(SvRV(map_ref)) != SVt_PVHV ) {
            SV *new_map_ref = newRV_noinc((SV *)newHV());
            sv_2mortal(new_map_ref);
            sv_setsv(map_ref, new_map_ref);
        }

        if ( !SvOK(cache_flag) || SvUV(cache_flag) != current ) {
            mop_update_method_map(aTHX_ self, class_name, stash, (HV *)SvRV(map_ref));
            sv_setuv(cache_flag, mop_check_package_cache_flag(aTHX_ stash)); /* update_cache_flag() */
        }

        XPUSHs(map_ref);

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Package, name, package);


SV*
add_package_symbol(SV* self, SV* variable, SV* ref = &PL_sv_undef)
PREINIT:
    svtype type;
    const char* type_name;
    const char* var_name;
    STRLEN var_name_len;
    GV* gv;
CODE:
    mop_deconstruct_variable_name(aTHX_ variable, &var_name, &var_name_len, &type, &type_name);
    gv = mop_get_gv(aTHX_ self, type, var_name, var_name_len, GV_ADDMULTI);

    if(SvOK(ref)){ /* add_package_symbol with a value */
        if(type == SVt_PV){
            if(!SvROK(ref)){
                ref = newRV_noinc(newSVsv(ref));
                sv_2mortal(ref);
            }
        }
        else if(!(SvROK(ref) && SvTYPE(SvRV(ref)) == type)){
            croak("You must pass a reference of %s for the value of %s", type_name, GvNAME(CvGV(cv)));
        }

        if(type == SVt_PVCV && GvCV(gv)){
            /* XXX: clear it before redefinition */
            SvREFCNT_dec(GvCV(gv));
            GvCV(gv) = NULL;
        }
        sv_setsv_mg((SV*)gv, ref); /* magical assignment into type glob (*glob = $ref) */

        if(type == SVt_PVCV){ /* name a subroutine */
            CV* const subr = (CV*)SvRV(ref);
            if(CvANON(subr)
                && CvGV(subr)
                && isGV(CvGV(subr))
                && strEQ(GvNAME(CvGV(subr)), "__ANON__")){

                CvGV(subr) = gv;
                CvANON_off(subr);
            }
        }
        RETVAL = ref;
        SvREFCNT_inc_simple_void_NN(ref);
    }
    else{
        SV* const sv = mop_gv_elem(aTHX_ gv, type, GV_ADDMULTI);
        RETVAL = (sv && GIMME_V != G_VOID) ? newRV_inc(sv) : &PL_sv_undef;
    }
OUTPUT:
    RETVAL

bool
has_package_symbol(SV* self, SV* variable)
PREINIT:
    svtype type;
    const char* type_name;
    const char* var_name;
    STRLEN var_name_len;
    GV* gv;
CODE:
    mop_deconstruct_variable_name(aTHX_ variable, &var_name, &var_name_len, &type, &type_name);
    gv = mop_get_gv(aTHX_ self, type, var_name, var_name_len, 0);
    RETVAL = mop_gv_elem(aTHX_ gv, type, FALSE) ? TRUE : FALSE;
OUTPUT:
    RETVAL

SV*
get_package_symbol(SV* self, SV* variable, ...)
PREINIT:
    svtype type;
    const char* type_name;
    const char* var_name;
    STRLEN var_name_len;
    I32 flags = 0;
    GV* gv;
    SV* sv;
CODE:
    { /* parse options */
        I32 i;
        if((items % 2) != 0){
            croak("Odd number of arguments for get_package_symbol()");
        }
        for(i = 2; i < items; i += 2){
            SV* const opt = ST(i);
            SV* const val = ST(i+1);
            if(strEQ(SvPV_nolen_const(opt), "create")){
                if(SvTRUE(val)){
                    flags |= GV_ADDMULTI;
                }
                else{
                    flags &= ~GV_ADDMULTI;
                }
            }
            else{
                warn("Unknown option \"%"SVf"\" for get_package_symbol()", opt);
            }
        }
    }
    mop_deconstruct_variable_name(aTHX_ variable, &var_name, &var_name_len, &type, &type_name);
    gv = mop_get_gv(aTHX_ self, type, var_name, var_name_len, flags);
    sv = mop_gv_elem(aTHX_ gv, type, FALSE);

    RETVAL = sv ? newRV_inc(sv) : &PL_sv_undef;
OUTPUT:
    RETVAL
