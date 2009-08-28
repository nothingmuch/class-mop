#include "mop.h"

#define _generate_constructor_method_xs(self, vtbl) mop_generate_constructor_method_xs(aTHX_ self, (mop_instance_vtbl*)vtbl)

static MGVTBL mop_constructor_vtbl;

static CV*
mop_generate_constructor_method_xs(pTHX_ SV* const metaclass, mop_instance_vtbl* const instance_vtbl){
   // CV* const xsub = newXS(NULL, mop_xs_constructor, __FILE__);

    assert(instance_vtbl);

}



MODULE = Class::MOP::Class    PACKAGE = Class::MOP::Class

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Class, get_attribute_map, attributes);
    INSTALL_SIMPLE_READER(Class, attribute_metaclass);
    INSTALL_SIMPLE_READER(Class, instance_metaclass);
    INSTALL_SIMPLE_READER(Class, immutable_trait);
    INSTALL_SIMPLE_READER(Class, constructor_name);
    INSTALL_SIMPLE_READER(Class, constructor_class);
    INSTALL_SIMPLE_READER(Class, destructor_class);

CV*
_generate_constructor_method_xs(SV* self, void* instance_vtbl)
