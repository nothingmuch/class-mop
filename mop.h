#ifndef __MOP_H__
#define __MOP_H__

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define MOP_CALL_BOOT(name)  mop_call_xs(aTHX_ name, cv, mark);

#ifndef XSPROTO
#define XSPROTO(name) XS(name)
#endif

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
extern SV *mop_VERSION;
extern SV *mop_ISA;

UV mop_check_package_cache_flag(pTHX_ HV *stash);
int mop_get_code_info (SV *coderef, char **pkg, char **name);
SV *mop_call0(pTHX_ SV *const self, SV *const method);
SV *mop_call1(pTHX_ SV *const self, SV *const method, SV *const arg1);

#define mop_call0_pvs(o, m)    mop_call0(aTHX_ o, newSVpvs_flags(m, SVs_TEMP))
#define mop_call1_pvs(o, m, a) mop_call1(aTHX_ o, newSVpvs_flags(m, SVs_TEMP), a)


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


/* Class::MOP::Instance stuff */

typedef struct {
    SV*  (*create_instance)(pTHX);
    bool (*has_slot)       (pTHX_ SV* const instance, SV* const slot_name);
    SV*  (*get_slot)       (pTHX_ SV* const instance, SV* const slot_name);
    SV*  (*set_slot)       (pTHX_ SV* const instance, SV* const slot_name, SV* const value);
    SV*  (*delete_slot)    (pTHX_ SV* const instance, SV* const slot_name);
    void (*weaken_slot)    (pTHX_ SV* const instance, SV* const slot_name);
} mop_instance_vtbl;

const mop_instance_vtbl* mop_get_default_instance_vtbl(pTHX);

#define MOP_mg_meta(mg) ((AV*)(mg)->mg_obj)
#ifdef DEBUGGING
#define MOP_mg_key(mg)  (*av_fetch( MOP_mg_meta(mg) , 0, TRUE))
#else
#define MOP_mg_key(mg)  (AvARRAY( MOP_mg_meta(mg))[0])
#endif
#define MOP_mg_vtbl(mg) ((const mop_instance_vtbl*)(mg)->mg_ptr)

/* Class::MOP::Method::Accessor stuff */

#define dMOP_METHOD_COMMON                                            \
    SV* const self      = mop_accessor_get_self(aTHX_ ax, items, cv); \
    MAGIC* const mg     = mop_accessor_get_mg(aTHX_ cv)               \


SV*    mop_accessor_get_self(pTHX_ I32 const ax, I32 const items, CV* const cv);
MAGIC* mop_accessor_get_mg(pTHX_ CV* const cv);

CV*    mop_install_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSPROTO(accessor_impl), const mop_instance_vtbl* vtbl);

#define INSTALL_SIMPLE_READER(klass, name)                  INSTALL_SIMPLE_READER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_READER_WITH_KEY(klass, name, key)    (void)mop_install_accessor(aTHX_ "Class::MOP::" #klass "::" #name, #key, sizeof(#key)-1, mop_xs_simple_reader, NULL)

#define INSTALL_SIMPLE_WRITER(klass, name)                  INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_WRITER_WITH_KEY(klass, name, key)    (void)mop_install_accessor(aTHX_ "Class::MOP::" #klass "::" #name, #key, sizeof(#key)-1, mop_xs_simple_writer, NULL)

#define INSTALL_SIMPLE_PREDICATE(klass, name)                INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, key) (void)mop_install_accessor(aTHX_ "Class::MOP::" #klass "::has_" #name, #key, sizeof(#key)-1, mop_xs_simple_predicate_for_metaclass, NULL)

#define MOPf_DIE_ON_FAIL 0x01
MAGIC* mop_mg_find(pTHX_ SV* const sv, const MGVTBL* const vtbl, I32 const flags);

#endif
