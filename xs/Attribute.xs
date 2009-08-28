#include "mop.h"

static MGVTBL mop_attr_vtbl;


MAGIC*
mop_attr_get_mg(pTHX_ SV* const attr){
    if(!SvROK(attr)) croak("Invalid object");

    return mop_mg_find(aTHX_ SvRV(attr), &mop_attr_vtbl, MOPf_DIE_ON_FAIL);
}


MODULE = Class::MOP::Attribute   PACKAGE = Class::MOP::Attribute

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Attribute, name);
    INSTALL_SIMPLE_READER(Attribute, associated_class);
    INSTALL_SIMPLE_READER(Attribute, associated_methods);
    INSTALL_SIMPLE_READER(Attribute, accessor);
    INSTALL_SIMPLE_READER(Attribute, reader);
    INSTALL_SIMPLE_READER(Attribute, writer);
    INSTALL_SIMPLE_READER(Attribute, predicate);
    INSTALL_SIMPLE_READER(Attribute, clearer);
    INSTALL_SIMPLE_READER(Attribute, builder);
    INSTALL_SIMPLE_READER(Attribute, init_arg);
    INSTALL_SIMPLE_READER(Attribute, initializer);
    INSTALL_SIMPLE_READER(Attribute, insertion_order);
    INSTALL_SIMPLE_READER(Attribute, definition_context);

    INSTALL_SIMPLE_WRITER_WITH_KEY(Attribute, _set_insertion_order, insertion_order);

    INSTALL_SIMPLE_PREDICATE(Attribute, accessor);
    INSTALL_SIMPLE_PREDICATE(Attribute, reader);
    INSTALL_SIMPLE_PREDICATE(Attribute, writer);
    INSTALL_SIMPLE_PREDICATE(Attribute, predicate);
    INSTALL_SIMPLE_PREDICATE(Attribute, clearer);
    INSTALL_SIMPLE_PREDICATE(Attribute, builder);
    INSTALL_SIMPLE_PREDICATE(Attribute, init_arg);
    INSTALL_SIMPLE_PREDICATE(Attribute, initializer);
    INSTALL_SIMPLE_PREDICATE(Attribute, default);

void
BUILD(SV* self)
PREINIT:
    mop_instance_vtbl* vtbl;
CODE:
    if(!( SvROK(self) && SvOBJECT(SvRV(self)) )){
        croak("Invalid object");
    }
    sv_magicext(SvRV(self), NULL, PERL_MAGIC_ext, &mop_attr_vtbl, NULL, 0);

