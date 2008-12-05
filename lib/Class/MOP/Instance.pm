
package Class::MOP::Instance;

use strict;
use warnings;

use Scalar::Util 'weaken', 'blessed';

our $VERSION   = '0.71_02';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

sub BUILDARGS {
    my ($class, @args) = @_;

    if ( @args == 1 ) {
        unshift @args, "associated_metaclass";
    } elsif ( @args >= 2 && blessed($args[0]) && $args[0]->isa("Class::MOP::Class") ) {
        # compat mode
        my ( $meta, @attrs ) = @args;
        @args = ( associated_metaclass => $meta, attributes => \@attrs );
    }

    my %options = @args;
    # FIXME lazy_build
    $options{slots} ||= [ map { $_->slots } @{ $options{attributes} || [] } ];
    $options{slot_hash} = { map { $_ => undef } @{ $options{slots} } }; # FIXME lazy_build

    return \%options;
}

sub new {
    my $class = shift;
    my $options = $class->BUILDARGS(@_);

    # FIXME replace with a proper constructor
    my $instance = $class->_new(%$options);

    # FIXME weak_ref => 1,
    weaken($instance->{'associated_metaclass'});

    return $instance;
}

sub _new {
    my ( $class, %options ) = @_;
    bless {
        # NOTE:
        # I am not sure that it makes
        # sense to pass in the meta
        # The ideal would be to just
        # pass in the class name, but
        # that is placing too much of
        # an assumption on bless(),
        # which is *probably* a safe
        # assumption,.. but you can
        # never tell <:)
        'associated_metaclass' => $options{associated_metaclass},
        'attributes'           => $options{attributes},
        'slots'                => $options{slots},
        'slot_hash'            => $options{slot_hash},
    } => $class;
}

sub _class_name { $_[0]->{_class_name} ||= $_[0]->associated_metaclass->name }

sub associated_metaclass { $_[0]{'associated_metaclass'} }

sub create_instance {
    my $self = shift;
    bless {}, $self->_class_name;
}

# for compatibility
sub bless_instance_structure {
    my ($self, $instance_structure) = @_;
    bless $instance_structure, $self->_class_name;
}

sub clone_instance {
    my ($self, $instance) = @_;
    bless { %$instance }, $self->_class_name;
}

# operations on meta instance

sub get_all_slots {
    my $self = shift;
    return @{$self->{'slots'}};
}

sub get_all_attributes {
    my $self = shift;
    return @{$self->{attributes}};
}

sub is_valid_slot {
    my ($self, $slot_name) = @_;
    exists $self->{'slot_hash'}->{$slot_name};
}

# operations on created instances

sub get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $instance->{$slot_name};
}

sub set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $instance->{$slot_name} = $value;
}

sub initialize_slot {
    my ($self, $instance, $slot_name) = @_;
    return;
}

sub deinitialize_slot {
    my ( $self, $instance, $slot_name ) = @_;
    delete $instance->{$slot_name};
}

sub initialize_all_slots {
    my ($self, $instance) = @_;
    foreach my $slot_name ($self->get_all_slots) {
        $self->initialize_slot($instance, $slot_name);
    }
}

sub deinitialize_all_slots {
    my ($self, $instance) = @_;
    foreach my $slot_name ($self->get_all_slots) {
        $self->deinitialize_slot($instance, $slot_name);
    }
}

sub is_slot_initialized {
    my ($self, $instance, $slot_name, $value) = @_;
    exists $instance->{$slot_name};
}

sub weaken_slot_value {
    my ($self, $instance, $slot_name) = @_;
    weaken $instance->{$slot_name};
}

sub strengthen_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $self->set_slot_value($instance, $slot_name, $self->get_slot_value($instance, $slot_name));
}

sub rebless_instance_structure {
    my ($self, $instance, $metaclass) = @_;
    bless $instance, $metaclass->name;
}

sub is_dependent_on_superclasses {
    return; # for meta instances that require updates on inherited slot changes
}

# inlinable operation snippets

sub is_inlinable { 1 }

sub inline_create_instance {
    my ($self, $class_variable) = @_;
    'bless {} => ' . $class_variable;
}

sub inline_slot_access {
    my ($self, $instance, $slot_name) = @_;
    sprintf "%s->{%s}", $instance, $slot_name;
}

sub inline_get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $self->inline_slot_access($instance, $slot_name);
}

sub inline_set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $self->inline_slot_access($instance, $slot_name) . " = $value",
}

sub inline_initialize_slot {
    my ($self, $instance, $slot_name) = @_;
    return '';
}

sub inline_deinitialize_slot {
    my ($self, $instance, $slot_name) = @_;
    "delete " . $self->inline_slot_access($instance, $slot_name);
}
sub inline_is_slot_initialized {
    my ($self, $instance, $slot_name) = @_;
    "exists " . $self->inline_slot_access($instance, $slot_name);
}

sub inline_weaken_slot_value {
    my ($self, $instance, $slot_name) = @_;
    sprintf "Scalar::Util::weaken( %s )", $self->inline_slot_access($instance, $slot_name);
}

sub inline_strengthen_slot_value {
    my ($self, $instance, $slot_name) = @_;
    $self->inline_set_slot_value($instance, $slot_name, $self->inline_slot_access($instance, $slot_name));
}

1;

__END__

=pod

=head1 NAME

Class::MOP::Instance - Instance Meta Object

=head1 DESCRIPTION

The meta instance is used by attributes for low level storage.

Using this API generally violates attribute encapsulation and is not
recommended, instead look at L<Class::MOP::Attribute/get_value>,
L<Class::MOP::Attribute/set_value> for the recommended way to fiddle with
attribute values in a generic way, independent of how/whether accessors have
been defined. Accessors can be found using L<Class::MOP::Class/get_attribute>.

This may seem like over-abstraction, but by abstracting
this process into a sub-protocol we make it possible to
easily switch the details of how an object's instance is
stored with minimal impact. In most cases just subclassing
this class will be all you need to do (see the examples;
F<examples/ArrayBasedStorage.pod> and
F<examples/InsideOutClass.pod> for details).

=head1 METHODS

=over 4

=item B<new %args>

Creates a new instance meta-object and gathers all the slots from
the list of C<@attrs> given.

=item B<BUILDARGS>

Processes arguments for compatibility.

=item B<meta>

Returns the metaclass of L<Class::MOP::Instance>.

=back

=head2 Creation of Instances

=over 4

=item B<create_instance>

This creates the appropriate structure needed for the instance and blesses it.

=item B<bless_instance_structure ($instance_structure)>

This does just exactly what it says it does.

This method has been deprecated but remains for compatibility reasons. None of
the subclasses of L<Class::MOP::Instance> ever bothered to actually make use of
it, so it was deemed unnecessary fluff.

=item B<clone_instance ($instance_structure)>

Creates a shallow clone of $instance_structure.

=back

=head2 Introspection

NOTE: There might be more methods added to this part of the API,
we will add then when we need them basically.

=over 4

=item B<associated_metaclass>

This returns the metaclass associated with this instance.

=item B<get_all_slots>

This will return the current list of slots based on what was
given to this object in C<new>.

=item B<is_valid_slot ($slot_name)>

This will return true if C<$slot_name> is a valid slot name.

=item B<is_dependent_on_superclasses>

This method returns true when the meta instance must be recreated on any
superclass changes.

Defaults to false.

=item B<get_all_attributes>

This will return the current list of attributes (as
Class::MOP::Attribute objects) based on what was given to this object
in C<new>.

=back

=head2 Operations on Instance Structures

An important distinction of this sub-protocol is that the
instance meta-object is a different entity from the actual
instance it creates. For this reason, any actions on slots
require that the C<$instance_structure> is passed into them.

The names of these methods pretty much explain exactly 
what they do, if that is not enough then I suggest reading 
the source, it is very straightfoward.

=over 4

=item B<get_slot_value ($instance_structure, $slot_name)>

=item B<set_slot_value ($instance_structure, $slot_name, $value)>

=item B<initialize_slot ($instance_structure, $slot_name)>

=item B<deinitialize_slot ($instance_structure, $slot_name)>

=item B<initialize_all_slots ($instance_structure)>

=item B<deinitialize_all_slots ($instance_structure)>

=item B<is_slot_initialized ($instance_structure, $slot_name)>

=item B<weaken_slot_value ($instance_structure, $slot_name)>

=item B<strengthen_slot_value ($instance_structure, $slot_name)>

=item B<rebless_instance_structure ($instance_structure, $new_metaclass)>

=back

=head2 Inlineable Instance Operations

=over 4

=item B<is_inlinable>

Each meta-instance should override this method to tell Class::MOP if it's
possible to inline the slot access. This is currently only used by 
L<Class::MOP::Immutable> when performing optimizations.

=item B<inline_create_instance>

=item B<inline_slot_access ($instance_structure, $slot_name)>

=item B<inline_get_slot_value ($instance_structure, $slot_name)>

=item B<inline_set_slot_value ($instance_structure, $slot_name, $value)>

=item B<inline_initialize_slot ($instance_structure, $slot_name)>

=item B<inline_deinitialize_slot ($instance_structure, $slot_name)>

=item B<inline_is_slot_initialized ($instance_structure, $slot_name)>

=item B<inline_weaken_slot_value ($instance_structure, $slot_name)>

=item B<inline_strengthen_slot_value ($instance_structure, $slot_name)>

=back

=head1 AUTHORS

Yuval Kogman E<lt>nothingmuch@woobling.comE<gt>

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

