
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

/*
check_method_cache_flag:
  check the PL_sub_generation 
  ISA/method cache thing

get_code_info:
  Pass in a coderef, returns:
  [ $pkg_name, $coderef_name ] ie:
  [ 'Foo::Bar', 'new' ]
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

void
get_code_info(coderef)
  SV* coderef
  PREINIT:
    char* name;
    char* pkg;
  PPCODE:
    if( SvOK(coderef) && SvROK(coderef) && SvTYPE(SvRV(coderef)) == SVt_PVCV){
      coderef = SvRV(coderef);
      name    = GvNAME( CvGV(coderef) );
      pkg     = HvNAME( GvSTASH(CvGV(coderef)) );

      EXTEND(SP, 2);
      PUSHs(newSVpvn(pkg, strlen(pkg)));
      PUSHs(newSVpvn(name, strlen(name)));
    }

