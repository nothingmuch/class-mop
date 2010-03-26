#include "mop.h"

struct mop_instance_St {
	mop_instance_type_t type;
	HV *stash;
    AV *attrs;
};

mop_instance_t *
mop_instance_new (mop_instance_type_t type, HV *stash)
{
	mop_instance_t *instance;

	Newx (instance, 1, mop_instance_t);
	instance->type = type;
	instance->stash = stash;
	instance->attrs = newAV();

	SvREFCNT_inc ((SV *)stash);

	return instance;
}

static void
initialize_attrs_from_perl_instance (mop_instance_t *instance, SV *perl_instance)
{
	dSP;
	I32 count;

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_instance);
	PUTBACK;

	count = call_method ("get_all_attributes", G_ARRAY);

	SPAGAIN;

	while (count--) {
		SV *perl_attr = POPs;
		mop_instance_add_attribute (instance, perl_attr);
	}

	PUTBACK;
	FREETMPS;
	LEAVE;
}

mop_instance_t *
mop_instance_new_from_perl_instance (SV *perl_instance)
{
	mop_instance_t *instance;
	dSP;
	I32 count;
	SV *class;

	if (!sv_derived_from (perl_instance, "Class::MOP::Instance")) {
		croak ("not a Class::MOP::Instance");
	}

	ENTER;
	SAVETMPS;

	PUSHMARK (SP);
	XPUSHs (perl_instance);
	PUTBACK;

	count = call_method ("_class_name", G_SCALAR);

	if (count != 1) {
		croak ("_class_name returned %d values, expected 1", (int)count);
	}

	SPAGAIN;

	class = POPs;

	/* TODO: don't hardcode type_hash */
	instance = mop_instance_new (mop_instance_type_hash, gv_stashsv (class, 0));

	PUTBACK;
	FREETMPS;
	LEAVE;

	initialize_attrs_from_perl_instance (instance, perl_instance);

	return instance;
}

void
mop_instance_destroy (mop_instance_t *instance)
{
    SvREFCNT_dec (instance->attrs);

	SvREFCNT_dec ((SV *)instance->stash);
	Safefree (instance);
}

mop_instance_t *_instance_build_c_instance(SV *perl_instance) {
    mop_instance_t *instance = mop_instance_new_from_perl_instance(perl_instance);
    mop_stash_in_mg(aTHX_ SvRV(perl_instance), NULL, (void *)instance, mop_instance_destroy);
    return instance;
}

mop_instance_t *mop_instance_get_c_instance (SV *perl_instance) {
    mop_instance_t *instance = mop_get_stashed_ptr_in_mg(aTHX_ SvRV(perl_instance));

    if ( instance )
        return instance;
    else
        return _instance_build_c_instance(perl_instance);
}


mop_instance_type_t
mop_instance_get_type (mop_instance_t *instance)
{
	return instance->type;
}

HV *
mop_instance_get_stash (mop_instance_t *instance)
{
	return instance->stash;
}

void
mop_instance_add_attribute (mop_instance_t *instance, SV *perl_attr)
{
    SV *copy = newSVsv(perl_attr);
	av_push( instance->attrs, copy );
    mop_attr_get_c_instance(copy);
}
