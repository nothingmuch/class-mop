#include "mop.h"


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
