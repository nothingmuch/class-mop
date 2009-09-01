#include "mop.h"


static MGVTBL mop_accessor_vtbl;


MAGIC*
mop_accessor_get_mg(pTHX_ CV* const xsub){
    return mop_mg_find(aTHX_ (SV*)xsub, &mop_accessor_vtbl, MOPf_DIE_ON_FAIL);
}

CV*
mop_install_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl, const mop_instance_vtbl* vtbl){
    CV* const xsub = newXS((char*)fq_name, accessor_impl, __FILE__);
    SV* const slot = newSVpvn_share(key, keylen, 0U);
    MAGIC* mg;

    if(!vtbl){
        vtbl = mop_get_default_instance_vtbl(aTHX);
    }

    if(!fq_name){
        /* generated_xsub need sv_2mortal */
        sv_2mortal((SV*)xsub);
    }

    mg = sv_magicext((SV*)xsub, slot, PERL_MAGIC_ext, &mop_accessor_vtbl, (char*)vtbl, 0);
    SvREFCNT_dec(slot); /* sv_magicext() increases refcnt in mg_obj */

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY slot for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}


CV*
mop_instantiate_xs_accessor(pTHX_ SV* const accessor, XSUBADDR_t const accessor_impl, mop_instance_vtbl* const vtbl){
    /* $slot = $accessor->associated_attribute->name */
    SV* const attr = mop_call0(aTHX_ accessor, mop_associated_attribute);
    SV* const slot = newSVsv_share(mop_call0(aTHX_ attr, mop_name));
    CV* const xsub = newXS(NULL, accessor_impl, __FILE__);
    MAGIC* mg;
    sv_2mortal((SV*)xsub);

    mg =  sv_magicext((SV*)xsub, slot, PERL_MAGIC_ext, &mop_accessor_vtbl, (char*)vtbl, 0);
    SvREFCNT_dec(slot); /* sv_magicext() increases refcnt in mg_obj */

    /* NOTE:
     * although we use MAGIC for gc, we also store mg to CvXSUBANY slot for efficiency (gfx)
     */
    CvXSUBANY(xsub).any_ptr = (void*)mg;

    return xsub;
}

SV*
mop_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv) {
    SV* self;

    if(items < 1){
        croak("too few arguments for %s", GvNAME(CvGV(cv)));
    }

    /* NOTE: If self has GETMAGIC, $self->accessor will invoke GETMAGIC
     *       before calling methods, so SvGETMAGIC(self) is not necessarily needed here.
     */

    self = ST(0);
    if(!IsObject(self)){
        croak("cant call %s as a class method", GvNAME(CvGV(cv)));
    }
    return self;
}

XS(mop_xs_simple_accessor)
{
    dVAR; dXSARGS;
    dMOP_METHOD_COMMON; /* self, mg */
    SV* value;

    if(items == 1){ /* reader */
        value = MOP_mg_get_slot(mg, self, MOP_mg_obj(mg));
    }
    else if (items == 2){ /* writer */
        value = MOP_mg_set_slot(mg, self, MOP_mg_obj(mg), ST(1));
    }
    else{
        croak("expected exactly one or two argument");
    }

    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}


XS(mop_xs_simple_reader)
{
    dVAR; dXSARGS;
    dMOP_METHOD_COMMON; /* self, mg */
    SV* value;

    if (items != 1) {
        croak("expected exactly one argument");
    }

    value = MOP_mg_get_slot(mg, self, MOP_mg_obj(mg));
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}

XS(mop_xs_simple_writer)
{
    dVAR; dXSARGS;
    dMOP_METHOD_COMMON; /* self, mg */

    if (items != 2) {
        croak("expected exactly two argument");
    }

    ST(0) = MOP_mg_set_slot(mg, self, MOP_mg_obj(mg), ST(1));
    XSRETURN(1);
}

XS(mop_xs_simple_clearer)
{
    dVAR; dXSARGS;
    dMOP_METHOD_COMMON; /* self, mg */
    SV* value;

    if (items != 1) {
        croak("expected exactly one argument");
    }

    value = MOP_mg_delete_slot(mg, self, MOP_mg_obj(mg));
    ST(0) = value ? value : &PL_sv_undef;
    XSRETURN(1);
}


XS(mop_xs_simple_predicate)
{
    dVAR; dXSARGS;
    dMOP_METHOD_COMMON; /* self, mg */

    if (items != 1) {
        croak("expected exactly one argument");
    }

    ST(0) = boolSV( MOP_mg_has_slot(mg, self, MOP_mg_obj(mg)) );
    XSRETURN(1);
}


XS(mop_xs_simple_predicate_for_metaclass)
{
    dVAR; dXSARGS;
    dMOP_METHOD_COMMON; /* self, mg */
    SV* value;

    if (items != 1) {
        croak("expected exactly one argument");
    }

    value = MOP_mg_get_slot(mg, self, MOP_mg_obj(mg));
    ST(0) = boolSV( value && SvOK(value ));
    XSRETURN(1);
}

MODULE = Class::MOP::Method::Accessor   PACKAGE = Class::MOP::Method::Accessor

PROTOTYPES: DISABLE

VERSIONCHECK: DISABLE

BOOT:
    INSTALL_SIMPLE_READER_WITH_KEY(Method::Accessor, associated_attribute, attribute);
    INSTALL_SIMPLE_READER(Method::Accessor, accessor_type);


CV*
_generate_accessor_method_xs(SV* self, void* instance_vtbl)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_accessor, instance_vtbl);
OUTPUT:
    RETVAL

CV*
_generate_reader_method_xs(SV* self, void* instance_vtbl)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_reader, instance_vtbl);
OUTPUT:
    RETVAL

CV*
_generate_writer_method_xs(SV* self, void* instance_vtbl)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_writer, instance_vtbl);
OUTPUT:
    RETVAL

CV*
_generate_predicate_method_xs(SV* self, void* instance_vtbl)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_predicate, instance_vtbl);
OUTPUT:
    RETVAL

CV*
_generate_clearer_method_xs(SV* self, void* instance_vtbl)
CODE:
    RETVAL = mop_instantiate_xs_accessor(aTHX_ self, mop_xs_simple_clearer, instance_vtbl);
OUTPUT:
    RETVAL

