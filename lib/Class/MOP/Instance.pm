
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
    my ($class, $meta, @attrs) = @_;
    my @slots = map { $_->name } @attrs;
    bless {
        meta  => $meta,
        slots => \@slots,
    } => $class; 
}

sub create_instance {
    my $self = shift;
    $self->bless_instance_structure({});
}

sub bless_instance_structure {
    my ($self, $instance_structure) = @_;
    bless $instance_structure, $self->{meta}->name;
}

# operations on meta instance

sub get_all_slots {
    my $self = shift;
    return @{$self->{slots}};
}

# operations on created instances

sub get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    return $instance->{$slot_name};
}

sub set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $instance->{$slot_name} = $value;
}

sub initialize_slot {
    my ($self, $instance, $slot_name) = @_;
    $instance->{$slot_name} = undef;
}

sub is_slot_initialized {
    my ($self, $instance, $slot_name, $value) = @_;
    exists $instance->{$slot_name} ? 1 : 0;
}

# inlinable operation snippets

sub inline_get_slot_value {
    my ($self, $instance_var_name, $slot_name) = @_;
    return ($instance_var_name . '->{\'' . $slot_name . '\'}');
}

sub inline_set_slot_value {
    my ($self, $instance_var_name, $slot_name, $value_name) = @_;
    return ($self->inline_get_slot_value($instance_var_name, $slot_name) . ' = ' . $value_name); 
}

sub inline_initialize_slot {
    my ($self, $instance_var_name, $slot_name) = @_;
    $self->inline_set_slot_value($instance_var_name, $slot_name, 'undef');
}

sub inline_is_slot_initialized {
    my ($self, $instance_var_name, $slot_name) = @_;
    return ('exists ' . $self->inline_get_slot_value($instance_var_name, $slot_name) . ' ? 1 : 0'); 
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

=item B<bless_instance_structure>

=item B<compute_layout_from_class>

=item B<create_instance>

=item B<get_all_slots>

=item B<get_slot_value>

=item B<set_slot_value>

=item B<initialize_slot>

=item B<is_slot_initialized>

=item B<inline_get_slot_value>

=item B<inline_set_slot_value>

=item B<inline_initialize_slot>

=item B<inline_is_slot_initialized>

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
