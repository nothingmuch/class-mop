#ifndef __MOP_H__
#define __MOP_H__

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define MOP_CALL_BOOT(name)  mop_call_xs(aTHX_ name, cv, mark);

void mop_call_xs (pTHX_ XSPROTO(subaddr), CV *cv, SV **mark);

#define MAKE_KEYSV(name) newSVpvn_share(#name, sizeof(#name)-1, 0U)

XS(mop_xs_simple_accessor);
XS(mop_xs_simple_reader);
XS(mop_xs_simple_writer);
XS(mop_xs_simple_predicate);
XS(mop_xs_simple_predicate_for_metaclass);
XS(mop_xs_simple_clearer);

extern SV *mop_method_metaclass;
extern SV *mop_associated_metaclass;
extern SV *mop_associated_attribute;
extern SV *mop_wrap;
extern SV *mop_methods;
extern SV *mop_name;
extern SV *mop_body;
extern SV *mop_package;
extern SV *mop_package_name;
extern SV *mop_package_cache_flag;
extern SV *mop_initialize;
extern SV *mop_can;
extern SV *mop_Class;
extern SV *mop_VERSION;
extern SV *mop_ISA;

/* MOP utilities */

UV mop_check_package_cache_flag(pTHX_ HV *stash);
int mop_get_code_info (SV *coderef, char **pkg, char **name);
SV *mop_call0(pTHX_ SV *const self, SV *const method);
SV *mop_call1(pTHX_ SV *const self, SV *const method, SV *const arg1);

#define mop_call0_pvs(o, m)    mop_call0(aTHX_ o, newSVpvs_flags(m, SVs_TEMP))
#define mop_call1_pvs(o, m, a) mop_call1(aTHX_ o, newSVpvs_flags(m, SVs_TEMP), a)

bool mop_is_class_loaded(pTHX_ SV*);
#define is_class_loaded(klass) mop_is_class_loaded(aTHX_ klass)

bool mop_is_instance_of(pTHX_ SV*, SV*);
#define is_instance_of(sv, klass)     mop_is_instance_of(aTHX_ sv, klass)
#define is_instance_of_pvs(sv, klass) mop_is_instance_of(aTHX_ sv, newSVpvs_flags(klass, SVs_TEMP))

typedef enum {
    TYPE_FILTER_NONE,
    TYPE_FILTER_CODE,
    TYPE_FILTER_ARRAY,
    TYPE_FILTER_IO,
    TYPE_FILTER_HASH,
    TYPE_FILTER_SCALAR,
} type_filter_t;

typedef bool (*get_package_symbols_cb_t) (const char *, STRLEN, SV *, void *);

void mop_get_package_symbols(HV *stash, type_filter_t filter, get_package_symbols_cb_t cb, void *ud);
HV  *mop_get_all_package_symbols (HV *stash, type_filter_t filter);


#define MOPf_DIE_ON_FAIL 0x01
MAGIC* mop_mg_find(pTHX_ SV* const sv, const MGVTBL* const vtbl, I32 const flags);

#ifdef DEBUGGING
#define MOP_av_at(av, ix)  *mop_av_at_safe(aTHX_ (av) , (ix))
SV** mop_av_at_safe(pTHX_ AV* const mi, I32 const ix);
#else
#define MOP_av_at(av, ix)  AvARRAY(av)[ix]
#endif

#define IsObject(sv) (SvROK(sv) && SvOBJECT(SvRV(sv)))

#define newSVsv_share(sv) mop_newSVsv_share(aTHX_ sv)
SV* mop_newSVsv_share(pTHX_ SV*);

SV* mop_class_of(pTHX_ SV* const sv);

/* Class::MOP::Class */

AV* mop_class_get_all_attributes(pTHX_ SV* const metaclass);

/* Class::MOP Magic stuff */

/* All the MOP_mg_* macros require MAGIC* mg for the first argument */

typedef struct {
    SV*  (*create_instance)(pTHX_ HV* const stash);
    bool (*has_slot)       (pTHX_ SV* const mi, SV* const instance);
    SV*  (*get_slot)       (pTHX_ SV* const mi, SV* const instance);
    SV*  (*set_slot)       (pTHX_ SV* const mi, SV* const instance, SV* const value);
    SV*  (*delete_slot)    (pTHX_ SV* const mi, SV* const instance);
    void (*weaken_slot)    (pTHX_ SV* const mi, SV* const instance);
} mop_instance_vtbl;

/* Class::MOP::Instance stuff */

SV*  mop_instance_create     (pTHX_ HV* const stash);
SV*  mop_instance_slot       (pTHX_ SV* const meta_instance, SV* const attr);
bool mop_instance_has_slot   (pTHX_ SV* const instance, SV* const slot);
SV*  mop_instance_get_slot   (pTHX_ SV* const instance, SV* const slot);
SV*  mop_instance_set_slot   (pTHX_ SV* const instance, SV* const slot, SV* const value);
SV*  mop_instance_delete_slot(pTHX_ SV* const instance, SV* const slot);
void mop_instance_weaken_slot(pTHX_ SV* const instance, SV* const slot);

const mop_instance_vtbl* mop_get_default_instance_vtbl(pTHX);

#define MOP_mg_obj(mg)   ((mg)->mg_obj)
#define MOP_mg_ptr(mg)   ((mg)->mg_ptr)
#define MOP_mg_vtbl(mg)  ((const mop_instance_vtbl*)MOP_mg_ptr(mg))
#define MOP_mg_flags(mg) ((mg)->mg_private)
#define MOP_mg_virtual(mg) ((mg)->mg_virtual)

#define MOP_mg_obj_refcounted_on(mg)    (void)((mg)->mg_flags |= MGf_REFCOUNTED);

#define MOP_mg_create_instance(mg, stash) MOP_mg_vtbl(mg)->create_instance (aTHX_ (stash))
#define MOP_mg_has_slot(mg, o, slot)      MOP_mg_vtbl(mg)->has_slot        (aTHX_ (o), (slot))
#define MOP_mg_get_slot(mg, o, slot)      MOP_mg_vtbl(mg)->get_slot        (aTHX_ (o), (slot))
#define MOP_mg_set_slot(mg, o, slot, v)   MOP_mg_vtbl(mg)->set_slot        (aTHX_ (o), (slot), (v))
#define MOP_mg_delete_slot(mg, o, slot)   MOP_mg_vtbl(mg)->delete_slot     (aTHX_ (o), (slot))
#define MOP_mg_weaken_slot(mg, o, slot)   MOP_mg_vtbl(mg)->weaken_slot     (aTHX_ (o), (slot))

/* Class::MOP::Attribute stuff */


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

enum mop_attr_flags_t{ /* keep 16 bits */
    MOP_ATTRf_HAS_INIT_ARG         = 0x0001,
    MOP_ATTRf_HAS_DEFAULT          = 0x0002,
    MOP_ATTRf_IS_DEFAULT_A_CODEREF = 0x0004,
    MOP_ATTRf_HAS_BUILDER          = 0x0008,
    MOP_ATTRf_HAS_INITIALIZER      = 0x0010,

    MOP_ATTRf_DEBUG                = 0x8000
};

MAGIC* mop_attr_mg(pTHX_ SV* const attr, SV* const instance);
void   mop_attr_initialize_instance_slot(pTHX_ SV* const attr, const mop_instance_vtbl* const vtbl, SV* const instance, HV* const args);

/* Class::MOP::Method::Accessor stuff */

#define dMOP_self      SV* const self = mop_accessor_get_self(aTHX_ ax, items, cv)
#define dMOP_mg(xsub)  MAGIC* mg      = (MAGIC*)CvXSUBANY(xsub).any_ptr
#define dMOP_METHOD_COMMON  dMOP_self; dMOP_mg(cv)


SV*    mop_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv);

CV*    mop_install_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSUBADDR_t const accessor_impl, const mop_instance_vtbl* vtbl);
CV*    mop_instantiate_xs_accessor(pTHX_ SV* const accessor, XSUBADDR_t const accessor_impl, mop_instance_vtbl* const vtbl);

#define INSTALL_SIMPLE_READER(klass, name)                  INSTALL_SIMPLE_READER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_READER_WITH_KEY(klass, name, key)    (void)mop_install_accessor(aTHX_ "Class::MOP::" #klass "::" #name, #key, sizeof(#key)-1, mop_xs_simple_reader, NULL)

#define INSTALL_SIMPLE_WRITER(klass, name)                  INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, key)    (void)mop_install_accessor(aTHX_ "Class::MOP::" #klass "::" #name, #key, sizeof(#key)-1, mop_xs_simple_writer, NULL)

#define INSTALL_SIMPLE_PREDICATE(klass, name)                INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, key) (void)mop_install_accessor(aTHX_ "Class::MOP::" #klass "::has_" #name, #key, sizeof(#key)-1, mop_xs_simple_predicate_for_metaclass, NULL)

#endif
