#ifndef __MOP_H__
#define __MOP_H__

#include "EXTERN.h"
#include "perl.h"

#define NO_XSLOCKS
#include "XSUB.h"

#define NEED_newRV_noinc
#define NEED_sv_2pv_flags
#define NEED_sv_2pv_nolen
#include "ppport.h"

#include "mop_attr.h"
#include "mop_instance.h"

#define MOP_CALL_BOOT(name)  mop_call_xs(aTHX_ name, cv, mark);

#ifndef XSPROTO
#define XSPROTO(name) XS(name)
#endif

void mop_call_xs (pTHX_ XSPROTO(subaddr), CV *cv, SV **mark);

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
SV *mop_prehashed_key_for (mop_prehashed_key_t key);
U32 mop_prehashed_hash_for (mop_prehashed_key_t key);

#define INSTALL_SIMPLE_READER(klass, name)  INSTALL_SIMPLE_READER_WITH_KEY(klass, name, name)
#define INSTALL_SIMPLE_READER_WITH_KEY(klass, name, key) \
    { \
        CV *cv = newXS("Class::MOP::" #klass "::" #name, mop_xs_simple_reader, __FILE__); \
        CvXSUBANY(cv).any_i32 = KEY_ ##key; \
    }

XS(mop_xs_simple_reader);

extern SV *mop_method_metaclass;
extern SV *mop_associated_metaclass;
extern SV *mop_wrap;

UV mop_check_package_cache_flag(pTHX_ HV *stash);
int mop_get_code_info (SV *coderef, char **pkg, char **name);
SV *mop_call0(pTHX_ SV *const self, SV *const method);
bool mop_call_predicate (SV *self, const char *method);

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

typedef struct mop_stashed_mg_St mop_stashed_mg_t;

struct mop_stashed_mg_St {
    void *ptr;
    void (*destructor)(void *);
};








static int mop_stashed_magic_free(pTHX_ SV *obj, MAGIC *mg) {
    mop_stashed_mg_t *stashed = (mop_stashed_mg_t *)mg->mg_ptr;

    if ( stashed ) {
        stashed->destructor(stashed->ptr);
        Safefree(stashed);
    }

    return 0;
}

static MGVTBL mop_stashed_mg_vtbl = {
    NULL, /* get */
    NULL, /* set */
    NULL, /* len */
    NULL, /* clear */
    mop_stashed_magic_free, /* free */
#if MGf_COPY
    NULL, /* copy */
#endif /* MGf_COPY */
#if MGf_DUP
    NULL, /* dup */
#endif /* MGf_DUP */
#if MGf_LOCAL
    NULL, /* local */
#endif /* MGf_LOCAL */
};


static MAGIC *mop_stash_in_mg (pTHX_ SV *sv, SV *obj, void *ptr, void (*destructor)(void *)) {
    mop_stashed_mg_t *stashed = NULL;
    MAGIC *mg;

    if ( ptr && destructor ) {
        Newx(stashed, 1, mop_stashed_mg_t);

        stashed->destructor = destructor;
        stashed->ptr = ptr;
    }

    mg = sv_magicext(sv, obj, PERL_MAGIC_ext, &mop_stashed_mg_vtbl, (void *)stashed, 0 );

    if ( obj )
        mg->mg_flags |= MGf_REFCOUNTED;

    return mg;
}


static MAGIC *mop_find_magic(pTHX_ SV *sv) {
    MAGIC *mg;

    if (SvTYPE(sv) >= SVt_PVMG) {
        for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
            if ((mg->mg_type == PERL_MAGIC_ext) && (mg->mg_virtual == &mop_stashed_mg_vtbl))
                break;
        }
        if (mg)
            return mg;
    }

    return NULL;
}

static SV *mop_get_stashed_obj_in_mg(pTHX_ SV *sv) {
    MAGIC *mg = mop_find_magic(aTHX_ sv);

    if ( mg )
        return mg->mg_obj;
    else
        return NULL;
}

static void *mop_get_stashed_ptr_in_mg(pTHX_ SV *sv) {
    MAGIC *mg = mop_find_magic(aTHX_ sv);

    if ( mg ) {
        mop_stashed_mg_t *stashed = (mop_stashed_mg_t *)mg->mg_ptr;
        return stashed->ptr;
    }
    else
        return NULL;
}




#endif
