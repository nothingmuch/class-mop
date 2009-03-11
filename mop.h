#ifndef __MOP_H__
#define __MOP_H__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define NEED_newRV_noinc
#define NEED_sv_2pv_flags
#define NEED_sv_2pv_nolen
#include "ppport.h"

#define MOP_CALL_BOOT(name) \
    { \
        EXTERN_C XS(name); \
        mop_call_xs(aTHX_ name, cv, mark); \
    }

void mop_call_xs (pTHX_ void (*subaddr) (pTHX_ CV *), CV *cv, SV **mark);

#define DECLARE_KEY(name)                    { #name, #name, NULL, 0 }
#define DECLARE_KEY_WITH_VALUE(name, value)  { #name, value, NULL, 0 }

typedef enum {
    KEY_name,
    KEY_package,
    KEY_package_name,
    KEY_body,
    KEY_package_cache_flag,
    KEY_methods,
    KEY_VERSION,
    KEY_ISA,
    key_last,
} mop_prehashed_key_t;

#define KEY_FOR(name)  mop_prehashed_key_for(KEY_ ##name)
#define HASH_FOR(name) mop_prehashed_hash_for(KEY_ ##name)

void mop_prehash_keys (void);
inline SV *mop_prehashed_key_for (mop_prehashed_key_t key);
inline U32 mop_prehashed_hash_for (mop_prehashed_key_t key);

extern SV *mop_method_metaclass;
extern SV *mop_associated_metaclass;
extern SV *mop_wrap;

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
