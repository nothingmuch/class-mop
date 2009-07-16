#define NEED_newSVpvn_flags
#include "mop.h"

static SV*
mop_deconstruct_variable_name(pTHX_ SV* const variable, svtype* const type, const char** const type_name) {
	SV* name;

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
		name = *svp;
		pv   = SvPV_const(name, len);
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

		name = newSVpvn_share(pv+1, len-1, 0U);
		sv_2mortal(name);
	}

	return name;
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

SV*
add_package_symbol(SV* self, SV* variable, SV* ref = &PL_sv_undef)
PREINIT:
	svtype type;
	const char* type_name;
	SV* var_name;
	SV* package_name;
	SV* fq_name;
CODE:
	var_name = mop_deconstruct_variable_name(aTHX_ variable, &type, &type_name);

	package_name = mop_call0(aTHX_ self, KEY_FOR(name));
	if(!SvOK(package_name)){
		croak("name() did not return a defined value");
	}
	fq_name = newSVpvf("%"SVf"::%"SVf, package_name, var_name);
	sv_2mortal(fq_name);

	if(SvOK(ref)){ /* set */
		GV* gv;
		if(type == SVt_PV){
			if(!SvROK(ref)){
				ref = newRV_noinc(newSVsv(ref));
				sv_2mortal(ref);
			}
		}
		else if(!(SvROK(ref) && SvTYPE(SvRV(ref)) == type)){
			croak("You must pass a reference of %s for the value of %s", type_name, GvNAME(CvGV(cv)));
		}
		gv = gv_fetchsv(fq_name, GV_ADDMULTI, type);

		if(type == SVt_PVCV && GvCV(gv)){
			/* XXX: should introduce an option { redefine => 1 } ? */
			SvREFCNT_dec(GvCV(gv));
			GvCV(gv) = NULL;
		}
		sv_setsv_mg((SV*)gv, ref); /* *glob = $ref */
		RETVAL = ref;
	}
	else { /* init */
		GV* const gv = gv_fetchsv(fq_name, GV_ADDMULTI, type);
		SV* sv;

		switch(type){
		case SVt_PV:
			sv = GvSVn(gv);
			break;
		case SVt_PVAV:
			sv = (SV*)GvAVn(gv);
			break;
		case SVt_PVHV:
			sv = (SV*)GvHVn(gv);
			break;
		case SVt_PVCV:
			sv = (SV*)GvCV(gv);
			break;
		case SVt_PVGV:
			sv = (SV*)gv;
			break;
		case SVt_PVIO:
			sv = (SV*)GvIOn(gv);
			break;
		default:
			croak("NOT REACHED");
			sv = NULL; /* -W */
			break;
		}

		if(sv){
			RETVAL = sv_2mortal(newRV_inc(sv));
		}
		else{
			RETVAL = &PL_sv_undef;
		}
	}
	ST(0) = RETVAL;

SV*
get_package_symbol(SV* self, SV* variable)
ALIAS:
	get_package_symbol = GV_ADDMULTI
	has_package_symbol = 0
PREINIT:
	svtype type;
	const char* type_name;
	SV* var_name;
	SV* package_name;
	SV* fq_name;
	GV* gv;
	SV* sv;
CODE:
	var_name = mop_deconstruct_variable_name(aTHX_ variable, &type, &type_name);

	package_name = mop_call0(aTHX_ self, KEY_FOR(name));
	if(!SvOK(package_name)){
		croak("name() did not return a defined value");
	}
	fq_name = newSVpvf("%"SVf"::%"SVf, package_name, var_name);
	sv_2mortal(fq_name);

	gv = gv_fetchsv(fq_name, ix, type);
	if(!gv){ /* no symbol in has_package_symbol() */
		XSRETURN_NO;
	}

	switch(type){
	case SVt_PV:
		sv = GvSV(gv);
		break;
	case SVt_PVAV:
		sv = (SV*)GvAV(gv);
		break;
	case SVt_PVHV:
		sv = (SV*)GvHV(gv);
		break;
	case SVt_PVCV:
		sv = (SV*)GvCV(gv);
		break;
	case SVt_PVGV:
		sv = (SV*)gv;
		break;
	case SVt_PVIO:
		sv = (SV*)GvIO(gv);
		break;
	default:
		croak("NOT REACHED");
		sv = NULL; /* -W */
		break;
	}

	if(!ix){ /* has_package_symbol */
		RETVAL = boolSV(sv);
	}
	else{
		if(sv){
			RETVAL = newRV_inc(sv);
		}
		else{
			RETVAL = &PL_sv_undef;
		}
	}
OUTPUT:
	RETVAL
