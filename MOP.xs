
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

/*
get_code_info:
  Pass in a coderef, returns:
  [ $pkg_name, $coderef_name ] ie:
  [ 'Foo::Bar', 'new' ]
*/

MODULE = Class::MOP   PACKAGE = Class::MOP

PROTOTYPES: ENABLE

void
get_code_info(coderef)
  SV* coderef
  PREINIT:
    char* name;
    char* pkg;
  PPCODE:
    if( SvOK(coderef) && SvROK(coderef) && SvTYPE(SvRV(coderef)) == SVt_PVCV){
      coderef = SvRV(coderef);
      /* I think this only gets triggered with a mangled coderef, but if
         we hit it without the guard, we segfault. The slightly odd return
         value strikes me as an improvement (mst)
      */
      //if (isGV_with_GP(CvGV(coderef))) {
        pkg     = HvNAME( GvSTASH(CvGV(coderef)) );
        name    = GvNAME( CvGV(coderef) );
      //} else {
      //  pkg     = "__UNKNOWN__";
      //  name    = "__ANON__";
      //}

      EXTEND(SP, 2);
      PUSHs(newSVpvn(pkg, strlen(pkg)));
      PUSHs(newSVpvn(name, strlen(name)));
    }

