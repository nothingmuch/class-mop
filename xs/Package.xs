
#include "mop.h"

#define GLOB_CREATE     0x01
#define VARIABLE_CREATE 0x02


static void
mop_deconstruct_variable_name(pTHX_ SV* const variable,
    const char** const var_name, STRLEN* const var_name_len,
    svtype* const type,
    const char** const type_name,
    I32* const flags) {


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

		svp = hv_fetchs(hv, "create", FALSE);
		if(svp && SvTRUE(*svp)){
			*flags = VARIABLE_CREATE | GLOB_CREATE;
		}
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

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Package, name, package);

#define S_HAS GV_NOADD_NOINIT
#define S_GET 0
#define S_ADD GV_ADDMULTI


SV*
add_package_symbol(SV* self, SV* variable, SV* ref = &PL_sv_undef)
ALIAS:
	has_package_symbol = S_HAS
	get_package_symbol = S_GET
	add_package_symbol = S_ADD
PREINIT:
	svtype type;
	const char* type_name;
	const char* var_name;
	STRLEN var_name_len;
	I32 flags = 0;
	GV** gvp;
	GV* gv;
CODE:
	if(items == 3 && ix != S_ADD){
		croak("Too many arguments for %s", GvNAME(CvGV(cv)));
	}

	mop_deconstruct_variable_name(aTHX_ variable, &var_name, &var_name_len, &type, &type_name, &flags);


	if(ix != S_ADD){ /* for shortcut fetching */
		SV* const ns = mop_call0(aTHX_ self, mop_namespace);
		HV* stash;
		if(!(SvROK(ns) && SvTYPE(SvRV(ns)) == SVt_PVHV)){
			croak("namespace() did not return a hash reference");
		}
		stash = (HV*)SvRV(ns);
		gvp = (GV**)hv_fetch(stash, var_name, var_name_len, FALSE);
	}
	else{
		gvp = NULL;
	}

	if(gvp && isGV(*gvp)){
		gv = *gvp;
	}
	else{
		SV* const package_name = mop_call0(aTHX_ self, KEY_FOR(name));
		const char* fq_name;

		if(!SvOK(package_name)){
			croak("name() did not return a defined value");
		}
		fq_name = Perl_form(aTHX_ "%"SVf"::%s", package_name, var_name);

		gv = gv_fetchpv(fq_name, ix | (flags & GLOB_CREATE ? GV_ADDMULTI : 0), type);
	}



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
			/* XXX: should introduce an option { redefine => 1 } ? */
			SvREFCNT_dec(GvCV(gv));
			GvCV(gv) = NULL;
		}
		sv_setsv_mg((SV*)gv, ref); /* *glob = $ref */
		RETVAL = ref;
	}
	else { /* no values */
		SV* sv;

		if(!gv){
			if(ix == S_HAS){
				XSRETURN_NO;
			}
			else{
				XSRETURN_UNDEF;
			}
		}

		if(!isGV(gv)){ /* In has_package_symbol, the stash entry is a stub or constant */
			assert(ix == S_HAS);
			if(type == SVt_PVCV){
				XSRETURN_YES;
			}
			else{
				XSRETURN_NO;
			}
		}

		switch(type){
		case SVt_PVAV:
			sv = (SV*)((flags & VARIABLE_CREATE) ? GvAVn(gv) : GvAV(gv));
			break;
		case SVt_PVHV:
			sv = (SV*)((flags & VARIABLE_CREATE) ? GvHVn(gv) : GvHV(gv));
			break;
		case SVt_PVCV:
			sv = (SV*)GvCV(gv);
			break;
		case SVt_PVIO:
			sv = (SV*)((flags & VARIABLE_CREATE) ? GvIOn(gv) : GvIO(gv));
			break;
		case SVt_PVGV:
			sv = (SV*)gv;
			break;
		default: /* SCALAR */
			sv =       (flags & VARIABLE_CREATE) ? GvSVn(gv) : GvSV(gv);
			break;
		}

		if(ix == S_HAS){
			RETVAL = boolSV(sv);
		}
		else{
			if(sv){
				RETVAL = sv_2mortal(newRV_inc(sv));
			}
			else{
				RETVAL = &PL_sv_undef;
			}
		}
	}
	ST(0) = RETVAL;

