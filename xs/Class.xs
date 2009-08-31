#include "mop.h"


AV*
mop_class_get_all_attributes(pTHX_ SV* const metaclass){
    AV* const attrs = newAV();
    dSP;
    I32 n;

    PUSHMARK(SP);
    XPUSHs(metaclass);
    PUTBACK;

    n = call_method("get_all_attributes", G_ARRAY);
    SPAGAIN;

    if(n){
        av_extend(attrs, n - 1);
        while(n){
            (void)av_store(attrs, --n, newSVsv(POPs));
        }
    }

    PUTBACK;

    return attrs;
}


MODULE = Class::MOP::Class    PACKAGE = Class::MOP::Class

PROTOTYPES: DISABLE

VERSIONCHECK: DISABLE

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Class, get_attribute_map, attributes);
    INSTALL_SIMPLE_READER(Class, attribute_metaclass);
    INSTALL_SIMPLE_READER(Class, instance_metaclass);
    INSTALL_SIMPLE_READER(Class, immutable_trait);
    INSTALL_SIMPLE_READER(Class, constructor_name);
    INSTALL_SIMPLE_READER(Class, constructor_class);
    INSTALL_SIMPLE_READER(Class, destructor_class);
