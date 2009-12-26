#include "mop.h"

MODULE = Class::MOP::Mixin::AttributeBase   PACKAGE = Class::MOP::Mixin::AttributeBase

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Mixin::AttributeBase, name);
