#ifndef __MOP_INSTANCE_H__
#define __MOP_INSTANCE_H__

typedef enum {
	mop_instance_type_hash
} mop_instance_type_t;

typedef struct mop_instance_St mop_instance_t;

mop_instance_t *mop_instance_new_from_perl_instance (SV *perl_instance);
void mop_instance_destroy (mop_instance_t *instance);

mop_instance_type_t mop_instance_get_type (mop_instance_t *instance);
HV *mop_instance_get_stash (mop_instance_t *instance);
void mop_instance_add_attribute (mop_instance_t *instance, mop_attr_t *attr);

#endif
