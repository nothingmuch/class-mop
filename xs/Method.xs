#include "mop.h"

MODULE = Class::MOP::Method   PACKAGE = Class::MOP::Method

PROTOTYPES: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Method, name);
    INSTALL_SIMPLE_READER(Method, package_name);
    INSTALL_SIMPLE_READER(Method, body);
    INSTALL_SIMPLE_READER(Method, associated_metaclass);
    INSTALL_SIMPLE_READER(Method, original_method);

    INSTALL_SIMPLE_WRITER_WITH_KEY(Method, _set_original_method, original_method);

MODULE = Class::MOP::Method   PACKAGE = Class::MOP::Method::Generated

BOOT:
    INSTALL_SIMPLE_READER(Method::Generated, is_inline);
    INSTALL_SIMPLE_READER(Method::Generated, definition_context);

MODULE = Class::MOP::Method   PACKAGE = Class::MOP::Method::Inlined

BOOT:
    INSTALL_SIMPLE_READER(Method::Inlined, _expected_method_class);
