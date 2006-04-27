
package Class::MOP::Instance;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype', 'weaken';

our $VERSION = '0.01';

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

sub new { 
    my ( $class, $meta ) = @_;
    bless {
        meta            => $meta,
        instance_layout => {}
    } => $class; 
}

sub create_instance {
    my ( $self, $class ) = @_;
    
    # rely on autovivification
    $self->bless_instance_structure( {}, $class );
}

sub bless_instance_structure {
    my ( $self, $instance_structure, $class ) = @_;
    $class ||= $self->{meta}->name;
    bless $instance_structure, $class;
}

sub get_all_parents {
    my $self = shift;
    my @parents = $self->{meta}->class_precedence_list;
    shift @parents; # shift off ourselves
    return map { $_->get_meta_instance } map { $_->meta || () } @parents;
}

# operations on meta instance

sub add_slot {
    my ($self, $slot_name ) = @_;
    confess "The slot '$slot_name' already exists"
        if 0 && $self->has_slot_recursively( $slot_name ); # FIXME
    $self->{instance_layout}->{$slot_name} = undef;
}

sub get_all_slots {
    my $self = shift;
    keys %{ $self->{instance_layout} };
}

sub get_all_slots_recursively {
    my $self = shift;
    return (
        $self->get_all_slots,
        map { $_->get_all_slots } $self->get_all_parents,
    ),
}

sub has_slot {
    my ($self, $slot_name) = @_;
    exists $self->{instance_layout}->{$slot_name} ? 1 : 0;
}

sub has_slot_recursively {
    my ( $self, $slot_name ) = @_;
    return 1 if $self->has_slot($slot_name);
    $_->has_slot_recursively($slot_name) && return 1 for $self->get_all_parents; 
    return 0;
}

sub remove_slot {
    my ( $self, $slot_name ) = @_;
    # NOTE:
    # this does not search recursively cause 
    # that is not the domain of this meta-instance
    # it is specific to this class ...
    confess "The slot '$slot_name' does not exist (maybe it's inherited?)"
        if 0 && $self->has_slot( $slot_name ); # FIXME
    delete $self->{instance_layout}->{$slot_name};
}


# operations on created instances

sub get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    return $instance->{$slot_name};
}

# can be called only after initialize_slot_value
sub set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $instance->{$slot_name} = $value;
}

# convenience method
# non autovivifying stores will have this as { initialize_slot unless slot_initlized; set_slot_value }
sub set_slot_value_with_init {
    my ( $self, $instance, $slot_name, $value ) = @_;
    $self->set_slot_value( $instance, $slot_name, $value );
}

sub initialize_slot {
    my ( $self, $instance, $slot_name ) = @_;
}

sub slot_initialized {
    my ($self, $instance, $slot_name) = @_;
    exists $instance->{$slot_name} ? 1 : 0;
}


# inlinable operation snippets

sub inline_get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    sprintf "%s->{%s}", $instance, $slot_name;
}

sub inline_set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $self->_inline_slot_lvalue . " = $value", 
}

sub inline_set_slot_value_with_init { 
    my ( $self, $instance, $slot_name, $value) = @_;
    $self->inline_set_slot_value( $instance, $slot_name, $value ) . ";";
}

sub inline_initialize_slot {
    return "";
}

sub inline_slot_initialized {
    my ($self, $instance, $slot_name) = @_;
    "exists " . $self->inline_get_slot_value;
}

sub _inline_slot_lvalue {
    my ($self, $instance, $slot_name) = @_;
    $self->inline_slot_value;
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Instance - Instance Meta Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<new>

=item B<add_slot>

=item B<bless_instance_structure>

=item B<create_instance>

=item B<get_all_parents>

=item B<get_slot_value>

=item B<has_slot>

=item B<has_slot_recursively>

=item B<initialize_slot>

=item B<inline_get_slot_value>

=item B<inline_initialize_slot>

=item B<inline_set_slot_value>

=item B<inline_set_slot_value_with_init>

=item B<inline_slot_initialized>

=item B<remove_slot>

=item B<set_slot_value>

=item B<set_slot_value_with_init>

=item B<slot_initialized>

=item B<get_all_slots>

=item B<get_all_slots_recursively>

=back

=head2 Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class.

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut