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

#define DECLARE_KEY(name) SV *key_##name; U32 hash_##name;
#define NEEDS_KEY(name) extern SV *key_##name; extern U32 hash_##name;

#define PREHASH_KEY_WITH_VALUE(name, value) do { \
    key_##name = newSVpvs(value); \
    PERL_HASH(hash_##name, value, sizeof(value) - 1); \
} while (0)

/* this is basically the same as the above macro, except that the value will be
 * the stringified name. However, we can't just implement this in terms of
 * PREHASH_KEY_WITH_VALUE as that'd cause macro expansion on the value of
 * 'name' when it's being passed to the other macro. suggestions on how to make
 * this more elegant would be much appreciated */

#define PREHASH_KEY(name) do { \
    key_##name = newSVpvs(#name); \
    PERL_HASH(hash_##name, #name, sizeof(#name) - 1); \
} while (0)

extern SV *method_metaclass;
extern SV *associated_metaclass;
extern SV *wrap;

UV mop_check_package_cache_flag(pTHX_ HV *stash);
int get_code_info (SV *coderef, char **pkg, char **name);
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

void get_package_symbols(HV *stash, type_filter_t filter, get_package_symbols_cb_t cb, void *ud);
HV *get_all_package_symbols (HV *stash, type_filter_t filter);

#endif
