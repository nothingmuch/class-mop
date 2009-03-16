#include "mop.h"

struct mop_instance_St {
	mop_instance_type_t type;
	HV *stash;
	UV n_attrs;
	mop_attr_t **attrs;
};

mop_instance_t *
mop_instance_new (mop_instance_type_t type, HV *stash)
{
	mop_instance_t *instance;

	Newx (instance, 1, mop_instance_t);
	instance->type = type;
	instance->stash = stash;
	instance->n_attrs = 0;
	instance->attrs = NULL;

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
		mop_instance_add_attribute (instance, mop_attr_new_from_perl_attr (perl_attr));
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
	U32 i;

	for (i = 0; i < instance->n_attrs; i++) {
		mop_attr_destroy (instance->attrs[i]);
	}

	Safefree (instance->attrs);
	SvREFCNT_dec ((SV *)instance->stash);
	Safefree (instance);
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
mop_instance_add_attribute (mop_instance_t *instance, mop_attr_t *attr)
{
	Renew (instance->attrs, instance->n_attrs + 1, mop_attr_t *);
	instance->attrs[instance->n_attrs] = attr;
	instance->n_attrs++;
}
