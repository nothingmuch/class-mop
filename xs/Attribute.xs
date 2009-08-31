#include "mop.h"


static MGVTBL mop_attr_vtbl;

MAGIC*
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

void
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


MODULE = Class::MOP::Attribute   PACKAGE = Class::MOP::Attribute

PROTOTYPES: DISABLE

VERSIONCHECK: DISABLE

BOOT:
    INSTALL_SIMPLE_READER(Attribute, name);
    INSTALL_SIMPLE_READER(Attribute, associated_class);
    INSTALL_SIMPLE_READER(Attribute, associated_methods);
    INSTALL_SIMPLE_READER(Attribute, accessor);
    INSTALL_SIMPLE_READER(Attribute, reader);
    INSTALL_SIMPLE_READER(Attribute, writer);
    INSTALL_SIMPLE_READER(Attribute, predicate);
    INSTALL_SIMPLE_READER(Attribute, clearer);
    INSTALL_SIMPLE_READER(Attribute, builder);
    INSTALL_SIMPLE_READER(Attribute, init_arg);
    INSTALL_SIMPLE_READER(Attribute, initializer);
    INSTALL_SIMPLE_READER(Attribute, insertion_order);
    INSTALL_SIMPLE_READER(Attribute, definition_context);

    INSTALL_SIMPLE_WRITER_WITH_KEY(Attribute, _set_insertion_order, insertion_order);

    INSTALL_SIMPLE_PREDICATE(Attribute, accessor);
    INSTALL_SIMPLE_PREDICATE(Attribute, reader);
    INSTALL_SIMPLE_PREDICATE(Attribute, writer);
    INSTALL_SIMPLE_PREDICATE(Attribute, predicate);
    INSTALL_SIMPLE_PREDICATE(Attribute, clearer);
    INSTALL_SIMPLE_PREDICATE(Attribute, builder);
    INSTALL_SIMPLE_PREDICATE(Attribute, init_arg);
    INSTALL_SIMPLE_PREDICATE(Attribute, initializer);
    INSTALL_SIMPLE_PREDICATE(Attribute, default);

