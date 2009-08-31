#include "mop.h"


static MGVTBL mop_attr_vtbl;

#define MOP_attr_slot(meta)          MOP_av_at(meta, MOP_ATTR_SLOT)
#define MOP_attr_init_arg(meta)      MOP_av_at(meta, MOP_ATTR_INIT_ARG)
#define MOP_attr_default(meta)       MOP_av_at(meta, MOP_ATTR_DEFAULT)
#define MOP_attr_builder(meta)       MOP_av_at(meta, MOP_ATTR_BUILDER)

enum mop_attr_ix_t{
    MOP_ATTR_SLOT,

    MOP_ATTR_INIT_ARG,
    MOP_ATTR_DEFAULT,
    MOP_ATTR_BUILDER,

    MOP_ATTR_last,
};

enum mop_attr_flags_t{ /* must be 16 bits */
    MOP_ATTRf_HAS_INIT_ARG         = 0x0001,
    MOP_ATTRf_HAS_DEFAULT          = 0x0002,
    MOP_ATTRf_IS_DEFAULT_A_CODEREF = 0x0004,
    MOP_ATTRf_HAS_BUILDER          = 0x0008,
    MOP_ATTRf_HAS_INITIALIZER      = 0x0010,


    MOP_ATTRf_DEBUG                = 0x8000
};

static MAGIC*
mop_attr_mg(pTHX_ SV* const attr, SV* const instance){
    MAGIC* mg;

    if(!IsObject(attr)) {
        croak("Invalid Attribute object");
    }

    /* attribute mg:
        mg_obj: meta information (AV*)
        mg_ptr: meta instance virtual table (mop_instance_vtbl*)
    */

    if(!(SvMAGICAL(SvRV(attr)) && (mg = mop_mg_find(aTHX_ SvRV(attr), &mop_attr_vtbl, 0))) ) {
        U16 flags = 0;
        AV* const meta = newAV();
        SV* name;
        SV* sv;

        mg = sv_magicext(SvRV(attr), (SV*)meta, PERL_MAGIC_ext, &mop_attr_vtbl, NULL, 0);
        SvREFCNT_dec(meta);
        av_extend(meta, MOP_ATTR_last - 1);

        ENTER;
        SAVETMPS;

        name = mop_call0(aTHX_ attr, mop_name);
        av_store(meta, MOP_ATTR_SLOT, newSVsv_share(name));

        if(SvOK( sv = mop_call0_pvs(attr, "init_arg") )) {
            flags |= MOP_ATTRf_HAS_INIT_ARG;

            av_store(meta, MOP_ATTR_INIT_ARG, newSVsv_share(sv));
        }

        /* NOTE: Setting both default and builder is not allowed */
        if(SvOK( sv = mop_call0_pvs(attr, "builder") )) {
            SV* const builder = sv;
            flags |= MOP_ATTRf_HAS_BUILDER;

            if(SvOK( sv = mop_call1(aTHX_ instance, mop_can, builder) )){
                av_store(meta, MOP_ATTR_BUILDER, newSVsv(sv));
            }
            else{
                croak("%s does not support builder method '%"SVf"' for attribute '%"SVf"'",
                    sv_reftype(SvRV(instance), TRUE), builder, name);
            }
        }
        else if(SvOK( sv = mop_call0_pvs(attr, "default") )) {
            if(SvTRUEx( mop_call0_pvs(attr, "is_default_a_coderef") )){
                flags |= MOP_ATTRf_HAS_BUILDER;
                av_store(meta, MOP_ATTR_BUILDER, newSVsv(sv));
            }
            else {
                flags |= MOP_ATTRf_HAS_DEFAULT;
                av_store(meta, MOP_ATTR_DEFAULT, newSVsv(sv));
            }
        }

        MOP_mg_flags(mg) = flags;

        if(flags & MOP_ATTRf_DEBUG) {
            warn("%s: setup attr_mg for '%"SVf"'\n", sv_reftype(SvRV(instance), TRUE), name);
        }

        FREETMPS;
        LEAVE;
    }

    return mg;
}

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

static void
mop_attr_initialize_instance_slot(pTHX_ SV* const attr, const mop_instance_vtbl* const vtbl, SV* const instance, HV* const args){
    MAGIC* const mg  = mop_attr_mg(aTHX_ attr, instance);
    AV* const meta   = (AV*)MOP_mg_obj(mg);
    U16 const flags  = MOP_mg_flags(mg);
    HE* arg;
    SV* value;

    if(flags & MOP_ATTRf_DEBUG){
        warn("%s: initialize_instance_slot '%"SVf"' (0x%04x)\n", sv_reftype(SvRV(instance), TRUE), MOP_attr_slot(meta), (unsigned)flags);
    }

    if( flags & MOP_ATTRf_HAS_INIT_ARG && (arg = hv_fetch_ent(args, MOP_attr_init_arg(meta), FALSE, 0U)) ){
        value = hv_iterval(args, arg);
    }
    else if(flags & MOP_ATTRf_HAS_DEFAULT) {
        value = MOP_attr_default(meta); /* it's always a non-ref value */
    }
    else if(flags & MOP_ATTRf_HAS_BUILDER) {
        SV* const builder = MOP_attr_builder(meta); /* code-ref default value or builder */
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(instance);
        PUTBACK;

        call_sv(builder, G_SCALAR);

        SPAGAIN;
        value = POPs;
        SvREFCNT_inc_simple_void_NN(value);
        PUTBACK;

        FREETMPS;
        LEAVE;

        sv_2mortal(value);
    }
    else{
        value = NULL;
    }

    if(value){
        if(flags & MOP_ATTRf_HAS_INITIALIZER){
            /* $attr->set_initial_value($meta_instance, $instance, $value) */
            dSP;

            PUSHMARK(SP);
            EXTEND(SP, 4);
            PUSHs(attr);
            PUSHs(instance);
            mPUSHs(value);
            PUTBACK;

            call_method("set_initial_value", G_VOID | G_DISCARD);
        }
        else{
            vtbl->set_slot(aTHX_ instance, MOP_attr_slot(meta), value);
        }
    }
}

static AV*
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

