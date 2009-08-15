#include "mop.h"

static CV*
mop_instantiate_xs_accessor(pTHX_ SV* const accessor, XSPROTO(accessor_impl)){
    /* $key = $accessor->associated_attribute->name */
    SV* const attr = mop_call0(aTHX_ accessor, mop_associated_attribute);
    SV* const key  = mop_call0(aTHX_ attr, mop_name);
    STRLEN len;
    const char* const pv = SvPV_const(key, len);
    return mop_install_simple_accessor(aTHX_ NULL /* anonymous */, pv, len, accessor_impl);
}

MODULE = Class::MOP::Method::Accessor   PACKAGE = Class::MOP::Method::Accessor

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Method::Accessor, associated_attribute, attribute);
    INSTALL_SIMPLE_READER(Method::Accessor, accessor_type);


CV*
_generate_accessor_method_xs(SV* self)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_accessor);
OUTPUT:
    RETVAL

CV*
_generate_reader_method_xs(SV* self)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_reader);
OUTPUT:
    RETVAL

CV*
_generate_writer_method_xs(SV* self)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_writer);
OUTPUT:
    RETVAL

CV*
_generate_predicate_method_xs(SV* self)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_predicate);
OUTPUT:
    RETVAL

CV*
_generate_clearer_method_xs(SV* self)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_clearer);
OUTPUT:
    RETVAL

