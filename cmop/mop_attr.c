#include "mop.h"

#undef ATTRFLAGS
#define ATTRFLAGS(attr)  (attr->flags)

typedef union {
	SV *sv;
	char *method;
	svtype type;
} default_t;

struct mop_attr_St {
	U32 flags;

	SV *slot_sv;    /* value of the slot (currently always slot name) */
	U32 slot_u32;   /* for optimized access (precomputed hash, possibly something else) */

	SV *init_arg_sv;  /* maybe the sv + U32 for hash keys should be a type of its own */
	U32 init_arg_u32;

	default_t default_value;
	CV *initializer;

	SV *perl_attr;
};

static void
initialize_slots (mop_attr_t *attr, SV *perl_attr)
{
	dSP;
	I32 count;
	SV *slot_sv;
	const char *slot_pv;
	STRLEN len;

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_attr);
	PUTBACK;

	count = call_method ("slots", G_ARRAY);

	if (count != 1) {
		croak ("currently only one slot per attr is supported");
	}

	SPAGAIN;

	slot_sv = POPs;
	slot_pv = SvPV (slot_sv, len);

	PERL_HASH (attr->slot_u32, slot_pv, len);
	attr->slot_sv = newSVpvn_share (slot_pv, len, attr->slot_u32);

	PUTBACK;
	FREETMPS;
	LEAVE;
	sv_dump (attr->slot_sv);
}

static void
initialize_init_arg (mop_attr_t *attr, SV *perl_attr)
{
	dSP;
	I32 count;
	SV *init_arg_sv;

	if (!mop_call_predicate (perl_attr, "has_init_arg")) {
		return;
	}

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_attr);
	PUTBACK;

	count = call_method ("init_arg", G_SCALAR);

	if (count != 1) {
		croak ("init_arg didn't return exactly one value");
	}

	SPAGAIN;

	init_arg_sv = POPs;
	if (init_arg_sv != &PL_sv_undef) {
		STRLEN len;
		const char *init_arg_pv = SvPV (init_arg_sv, len);
		PERL_HASH (attr->init_arg_u32, init_arg_pv, len);
		attr->init_arg_sv = newSVpvn_share (init_arg_pv, len, attr->init_arg_u32);
		ATTRFLAGS(attr) |= ATTR_INIT_ARG;
	}

	PUTBACK;
	FREETMPS;
	LEAVE;
}

static bool
is_simple_refgen (CV *cv, svtype *default_type)
{
	/* TODO: inspect cv root. see if it it only creates a new empty anonymous reference */
	return FALSE;
}

static void
initialize_default_normal (mop_attr_t *attr, SV *perl_attr)
{
	dSP;
	I32 count;
	SV *default_sv;

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_attr);
	PUTBACK;

	count = call_method ("default", G_SCALAR);

	if (count != 1) {
		croak ("default didn't return exactly one value");
	}

	SPAGAIN;

	default_sv = POPs;
	if (SvROK (default_sv)) {
		svtype default_type;

		if (SvTYPE (SvRV (default_sv)) != SVt_PVCV) {
			croak ("default value reference is not a coderef");
		}

		if (is_simple_refgen ((CV *)SvRV (default_sv), &default_type)) {
			attr->default_value.type = default_type;
			ATTRFLAGS (attr) |= (mop_attr_default_refgen << ATTR_DEFAULT_SHIFT);
		}
		else {
			attr->default_value.sv = newSVsv (default_sv);
			ATTRFLAGS (attr) |= (ATTR_DEFAULT_REFCOUNTED | (mop_attr_default_normal << ATTR_DEFAULT_SHIFT));
		}
	}
	else {
		attr->default_value.sv = newSVsv (default_sv);
		ATTRFLAGS (attr) |= (ATTR_DEFAULT_REFCOUNTED | (mop_attr_default_normal << ATTR_DEFAULT_SHIFT));
	}

	PUTBACK;
	FREETMPS;
	LEAVE;
}

static void
initialize_default_builder (mop_attr_t *attr, SV *perl_attr)
{
	dSP;
	I32 count;
	const char *builder;
	STRLEN len;

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_attr);
	PUTBACK;

	count = call_method ("builder", G_SCALAR);

	if (count != 1) {
		croak ("builder didn't return exactly one value");
	}

	SPAGAIN;

	builder = SvPV (POPs, len);
	attr->default_value.method = savepvn (builder, len);
	ATTRFLAGS (attr) |= (mop_attr_default_builder << ATTR_DEFAULT_SHIFT);

	PUTBACK;
	FREETMPS;
	LEAVE;
}

static void
initialize_default (mop_attr_t *attr, SV *perl_attr)
{
	if (mop_call_predicate (perl_attr, "has_default")) {
		initialize_default_normal (attr, perl_attr);
	}
	else if (mop_call_predicate (perl_attr, "has_builder")) {
		initialize_default_builder (attr, perl_attr);
	}
}

static void
initialize_initializer (mop_attr_t *attr, SV *perl_attr)
{
	dSP;
	I32 count;
	SV *initializer;

	if (!mop_call_predicate (perl_attr, "has_initializer")) {
		return;
	}

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_attr);
	PUTBACK;

	count = call_method ("initializer", G_SCALAR);

	if (count != 1) {
		croak ("initializer didn't return exactly one value");
	}

	SPAGAIN;

	initializer = POPs;

	if (!SvROK (initializer) || (SvTYPE (SvRV (initializer)) != SVt_PVCV)) {
		croak ("initializer is not a code reference");
	}

	attr->initializer = (CV *)SvRV (initializer);
	SvREFCNT_inc ((SV *)attr->initializer);
	ATTRFLAGS (attr) |= ATTR_INITIALIZER;

	PUTBACK;
	FREETMPS;
	LEAVE;
}

mop_attr_t *
mop_attr_new_from_perl_attr (SV *perl_attr)
{
	/* TODO: break this up so constructing a mop_attr_t from c space is easy */
	mop_attr_t *attr;
	dXCPT;

	Newxz (attr, 1, mop_attr_t);
	attr->perl_attr = newSVsv (perl_attr); /* RAFL IS TEH BEST OMGIGOD */

	XCPT_TRY_START {
		initialize_slots (attr, perl_attr);
		initialize_init_arg (attr, perl_attr);
		initialize_default (attr, perl_attr);
		initialize_initializer (attr, perl_attr);
	} XCPT_TRY_END

	XCPT_CATCH {
		mop_attr_destroy (attr);
		XCPT_RETHROW;
	}

	warn ("creating attr with slot value 0x%x", (unsigned int)attr->slot_sv);

	return attr;
}

void
mop_attr_destroy (mop_attr_t *attr)
{
	warn ("destroying attr 0x%x", (unsigned int)attr);

	if (attr->slot_sv) {
		SvREFCNT_dec (attr->slot_sv);
	}

	if (ATTR_HAS_INIT_ARG (attr) && attr->init_arg_sv) {
		SvREFCNT_dec (attr->init_arg_sv);
	}

	if (ATTR_HAS_INITIALIZER (attr) && attr->initializer) {
		SvREFCNT_dec ((SV *)attr->initializer);
	}

	switch (ATTR_DEFAULT_TYPE (attr)) {
		case mop_attr_default_builder:
			free (attr->default_value.method);
			break;
		case mop_attr_default_normal:
			if (ATTRFLAGS (attr) & ATTR_DEFAULT_REFCOUNTED) {
				SvREFCNT_dec (attr->default_value.sv);
			}
			break;
		default: /* refgen and none */
			break;
	}

	SvREFCNT_dec (attr->perl_attr);
	Safefree (attr);
}

U32
mop_attr_get_flags (mop_attr_t *attr)
{
	return attr->flags;
}

SV *
mop_attr_get_perl_attr (mop_attr_t *attr)
{
	return attr->perl_attr;
}
