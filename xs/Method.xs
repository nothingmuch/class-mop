#include "mop.h"

MODULE = Class::MOP::Method   PACKAGE = Class::MOP::Method

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Method, name);
    INSTALL_SIMPLE_READER(Method, package_name);
    INSTALL_SIMPLE_READER(Method, body);
    INSTALL_SIMPLE_READER(Method, associated_metaclass);
    INSTALL_SIMPLE_READER(Method, original_method);
