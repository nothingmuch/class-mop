
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
    my $class = shift;
    my $meta  = shift;
    bless {
        instance => (bless {} => $meta->name)
    } => $class; 
}

sub add_slot {
    my ($self, $slot_name, $value) = @_;
    return $self->{instance}->{$slot_name} = $value;
}

sub has_slot {
    my ($self, $slot_name) = @_;
    exists $self->{instance}->{$slot_name} ? 1 : 0;
}

sub get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    return $instance->{$slot_name};
}

sub set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $instance->{$slot_name} = $value;
}

sub has_slot_value {
    my ($self, $instance, $slot_name) = @_;
    defined $instance->{$slot_name} ? 1 : 0;
}

sub get_instance { (shift)->{instance} }

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

=item B<has_slot>

=item B<get_slot_value>

=item B<set_slot_value>

=item B<has_slot_value>

=item B<get_instance>

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