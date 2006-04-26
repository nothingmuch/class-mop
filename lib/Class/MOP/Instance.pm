
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
        instance => bless {} => $meta->name
    } => $class; 
}

sub add_slot {
    my ($self, $slot_name, $value) = @_;
    return $self->{instance}->{$slot_name} = $value;
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