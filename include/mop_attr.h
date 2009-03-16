#ifndef __MOP_ATTR_H__
#define __MOP_ATTR_H__

typedef enum {
	mop_attr_default_none    = 1 << 0,
	mop_attr_default_normal  = 1 << 1,
	mop_attr_default_builder = 1 << 2,
	mop_attr_default_refgen  = 1 << 3
} mop_attr_default_type_t;

#define ATTRFLAGS(attr)  mop_attr_get_flags(attr)

#define ATTR_WRITING_MASK  0x000000ff
#define ATTR_READING_MASK  0x0000ff00
#define ATTR_INSTANCE_MASK 0xff000000

#define ATTR_WRITING_FLAGS(attr)  (ATTRFLAGS (attr) & ATTR_WRITING_MASK)
#define ATTR_READING_FLAGS(attr)  (ATTRFLAGS (attr) & ATTR_READING_MASK)
#define ATTR_INSTANCE_FLAGS(attr) (ATTRFLAGS (attr) & ATTR_INSTANCE_MASK)

#define ATTR_DEFAULT_MASK 0x700
#define ATTR_DEFAULT_SHIFT 8
#define ATTR_DEFAULT_REFCOUNTED 0x1000

#define ATTR_DEFAULT_TYPE(attr)  ((mop_attr_default_type_t)((ATTR_READING_FLAGS (attr) & ATTR_DEFAULT_MASK) >> ATTR_DEFAULT_SHIFT))

#define ATTR_INIT_ARG    0x20000
#define ATTR_INITIALIZER 0x40000

#define ATTR_HAS_INIT_ARG(attr)     (ATTRFLAGS (attr) & ATTR_INIT_ARG)
#define ATTR_HAS_INITIALIZER(attr)  (ATTRFLAGS (attr) & ATTR_INITIALIZER)

typedef struct mop_attr_St mop_attr_t;

mop_attr_t *mop_attr_new_from_perl_attr (SV *perl_attr);
void mop_attr_destroy (mop_attr_t *attr);
U32 mop_attr_get_flags (mop_attr_t *attr);
SV *mop_attr_get_perl_attr (mop_attr_t *attr);

#endif
