package Class::MOP::HasAttributes;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';
use Try::Tiny;

use base 'Class::MOP::Object';

sub _attribute_map      { $_[0]->{'attributes'} }
sub attribute_metaclass { $_[0]->{'attribute_metaclass'} }

sub add_attribute {
    my $self = shift;

    # either we have an attribute object already
    # or we need to create one from the args provided
    my $attribute
        = blessed( $_[0] ) ? $_[0] : $self->attribute_metaclass->new(@_);

    # make sure it is derived from the correct type though
    ( $attribute->isa('Class::MOP::Attribute') )
        || confess
        "Your attribute must be an instance of Class::MOP::Attribute (or a subclass)";

    # first we attach our new attribute
    # because it might need certain information
    # about the class which it is attached to
    $attribute->attach_to_class($self);

    my $attr_name = $attribute->name;

    # then we remove attributes of a conflicting
    # name here so that we can properly detach
    # the old attr object, and remove any
    # accessors it would have generated
    if ( $self->has_attribute($attr_name) ) {
        $self->remove_attribute($attr_name);
    }
    else {
        $self->invalidate_meta_instances()
            if $self->can('invalidate_meta_instances');
    }

    # get our count of previously inserted attributes and
    # increment by one so this attribute knows its order
    my $order = ( scalar keys %{ $self->_attribute_map } );
    $attribute->_set_insertion_order($order);

    # then onto installing the new accessors
    $self->_attribute_map->{$attr_name} = $attribute;

    # invalidate package flag here
    try {
        local $SIG{__DIE__};
        $attribute->install_accessors();
    }
    catch {
        $self->remove_attribute($attr_name);
        die $_;
    };

    return $attribute;
}

sub has_attribute {
    my ( $self, $attribute_name ) = @_;

    ( defined $attribute_name )
        || confess "You must define an attribute name";

    exists $self->_attribute_map->{$attribute_name};
}

sub get_attribute {
    my ( $self, $attribute_name ) = @_;

    ( defined $attribute_name )
        || confess "You must define an attribute name";

    return $self->_attribute_map->{$attribute_name};
}

sub remove_attribute {
    my ( $self, $attribute_name ) = @_;

    ( defined $attribute_name )
        || confess "You must define an attribute name";

    my $removed_attribute = $self->_attribute_map->{$attribute_name};
    return unless defined $removed_attribute;

    delete $self->_attribute_map->{$attribute_name};
    $self->invalidate_meta_instances()
        if $self->can('invalidate_meta_instances');
    $removed_attribute->remove_accessors();
    $removed_attribute->detach_from_class();

    return $removed_attribute;
}

sub get_attribute_list {
    my $self = shift;
    keys %{ $self->_attribute_map };
}

sub find_attribute_by_name {
    my ( $self, $attr_name ) = @_;

    foreach my $class ( $self->linearized_isa ) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        return $meta->get_attribute($attr_name)
            if $meta->has_attribute($attr_name);
    }

    return;
}

1;
