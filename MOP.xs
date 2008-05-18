
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

/*
check_method_cache_flag:
  check the PL_sub_generation 
  ISA/method cache thing
*/

MODULE = Class::MOP   PACKAGE = Class::MOP

PROTOTYPES: ENABLE

SV*
check_package_cache_flag(pkg)
  SV* pkg
  CODE:
    RETVAL = newSViv(PL_sub_generation);
  OUTPUT:
    RETVAL

