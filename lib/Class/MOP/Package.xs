#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Class::MOP::Package    PACKAGE = Class::MOP::Package PREFIX = CMP_

void
CMP_remove_package_symbol( self, variable )
    SV* self
    SV* variable
INIT:
    SV* name         = NULL;
    SV* package      = NULL;
    SV* sigil        = NULL;
    SV* type         = NULL;
    GV* symbol       = NULL;
    HV* stash        = NULL;
    char* type_s     = NULL;
CODE:
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK( SP );
    XPUSHs( self );
    XPUSHs( variable );
    PUTBACK;

    call_method( "_deconstruct_variable_name", G_ARRAY );

    SPAGAIN;
    type  = POPs;
    sigil = POPs;
    name  = POPs;

    PUSHMARK( SP );
    XPUSHs( self );
    PUTBACK;

    call_method( "namespace", G_SCALAR );

    SPAGAIN;
    stash      = (HV*)( SvRV( POPs ) );

    PUSHMARK( SP );
    XPUSHs( self );
    PUTBACK;

    call_method( "name", G_SCALAR );

    package    = POPs;
    symbol     = *(GV**)hv_fetch( stash, SvPV_nolen( name ), sv_len( name ), 0);
    type_s     = SvPV_nolen( type );

    if (strEQ( type_s, "SCALAR" ))
    {
        SvREFCNT_dec( GvSV( symbol ) );
        GvSV( symbol ) = &PL_sv_undef;
    }
    else if (strEQ( type_s, "ARRAY" ))
    {
        SvREFCNT_dec( GvAV( symbol ) );
        GvAV( symbol ) = NULL;
    }
    else if (strEQ( type_s, "HASH" ))
    {
        SvREFCNT_dec( GvHV( symbol ) );
        GvHV( symbol ) = NULL;
    }
    else if (strEQ( type_s, "CODE" ))
    {
        SvREFCNT_dec( GvCV( symbol ) );
        GvCV( symbol ) = NULL;
    }

    FREETMPS;
    LEAVE;
