#ifndef __MOP_H__
#define __MOP_H__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_newRV_noinc
#define NEED_sv_2pv_flags
#define NEED_sv_2pv_nolen
#include "ppport.h"

#define MOP_CALL_BOOT(name)  mop_call_xs(aTHX_ name, cv, mark);

#ifndef XSPROTO
#define XSPROTO(name) XS(name)
#endif

void mop_call_xs (pTHX_ XSPROTO(subaddr), CV *cv, SV **mark);


#define MAKE_KEYSV(name) newSVpvn_share(#name, sizeof(#name)-1, 0U)

CV* mop_install_simple_accessor(pTHX_ const char* const fq_name, const char* const key, I32 const keylen, XSPROTO(accessor_impl));

#define INSTALL_SIMPLE_READER(klass, name)  INSTALL_SIMPLE_READER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_READER_WITH_KEY(klass, name, key) (void)mop_install_simple_accessor(aTHX_ "Class::MOP::" #klass "::" #name, #key, sizeof(#key)-1, mop_xs_simple_reader)

#define INSTALL_SIMPLE_PREDICATE(klass, name)  INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_PREDICATE_WITH_KEY(klass, name, key) (void)mop_install_simple_accessor(aTHX_ "Class::MOP::" #klass "::has_" #name, #key, sizeof(#key)-1, mop_xs_simple_predicate_for_metaclass)


XS(mop_xs_simple_accessor);
XS(mop_xs_simple_reader);
XS(mop_xs_simple_writer);
XS(mop_xs_simple_predicate);
XS(mop_xs_simple_predicate_for_metaclass);
XS(mop_xs_simple_clearer);

extern SV *mop_method_metaclass;
extern SV *mop_associated_metaclass;
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
HV *mop_get_all_package_symbols (HV *stash, type_filter_t filter);

#endif
