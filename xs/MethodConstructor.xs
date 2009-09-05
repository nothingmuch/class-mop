#include "mop.h"


static MGVTBL mop_constructor_vtbl;

static HV*
mop_build_args(pTHX_ CV* const cv, I32 const ax, I32 const items){
    HV* args;
    if(items == 1){
        SV* const sv = ST(0);
        SvGETMAGIC(sv);
        if(!(SvROK(sv) && SvTYPE(SvRV(sv)) == SVt_PVHV)){
            croak("Single arguments to %s() must be a HASH ref", GvNAME(CvGV(cv)));
        }
        args = (HV*)SvRV(sv);
    }
    else{
        I32 i;

        if( items % 2 ){
            croak("Odd number of arguments for %s()", GvNAME(CvGV(cv)));
        }

        args = newHV();
        sv_2mortal((SV*)args);

        for(i = 0; i < items; i += 2){
            SV* const key   = ST(i);
            SV* const value = ST(i+1);
            (void)hv_store_ent(args, key, value, 0U);
            SvREFCNT_inc_simple_void_NN(value);
        }
    }
    return args;
}


XS(mop_xs_constructor);
XS(mop_xs_constructor)
{
    dVAR; dXSARGS;
    dMOP_mg(cv);
    AV* const attrs = (AV*)MOP_mg_obj(mg);
    SV* klass;
    HV* stash;
    SV* instance;
    I32 i;
    I32 len;
    HV* args;

    assert(SvTYPE(attrs) == SVt_PVAV);

    if(items < 0){
        croak("Not enough arguments for %s()", GvNAME(CvGV(cv)));
    }

    SP -= items;
    PUTBACK;

    klass = ST(0);

    if(SvROK(klass)){
        croak("The constructor must be called as a class method");
    }

    args = mop_build_args(aTHX_ cv, ax+1, items-1);

    stash = gv_stashsv(klass, TRUE);
    if( stash != GvSTASH(CvGV(cv)) ){
        SV* const metaclass = mop_class_of(aTHX_ klass);
        dSP;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(metaclass);
        mPUSHs(newRV_inc((SV*)args));
        PUTBACK;

        call_method("new_object", GIMME_V);
        return;
    }

    instance = sv_2mortal( MOP_mg_create_instance(mg, stash) );
    if(!IsObject(instance)){
        croak("create_instance() did not return an object instance");
    }

    len = AvFILLp(attrs) + 1;
    for(i = 0; i < len; i++){
        mop_attr_initialize_instance_slot(aTHX_ AvARRAY(attrs)[i], MOP_mg_vtbl(mg), instance, args);
    }

    ST(0) = instance;
    XSRETURN(1);
}


static CV*
mop_generate_constructor_method_xs(pTHX_ SV* const constructor, mop_instance_vtbl* const vtbl){
    SV* const metaclass = mop_call0(aTHX_ constructor, mop_associated_metaclass);

    CV* const xsub  = newXS(NULL, mop_xs_constructor, __FILE__);
    MAGIC* mg;
    AV* attrs;

    sv_2mortal((SV*)xsub);

    attrs = mop_class_get_all_attributes(aTHX_ metaclass);
    mg = sv_magicext((SV*)xsub, (SV*)attrs, PERL_MAGIC_ext, &mop_constructor_vtbl, (char*)vtbl, 0);
    SvREFCNT_dec(attrs);
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}


MODULE = Class::MOP::Method::Constructor   PACKAGE = Class::MOP::Method::Constructor

PROTOTYPES: DISABLE

VERSIONCHECK: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Method::Constructor, options);
    INSTALL_SIMPLE_READER(Method::Constructor, associated_metaclass);

CV*
_generate_constructor_method_xs(SV* self, void* instance_vtbl)
CODE:
    RETVAL = mop_generate_constructor_method_xs(aTHX_ self, instance_vtbl);
OUTPUT:
    RETVAL

