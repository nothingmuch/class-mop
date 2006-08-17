
package Class::MOP::Module;

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Package';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

sub version {  
    my $self = shift;
    ${$self->get_package_symbol('$VERSION')};
}

sub authority {  
    my $self = shift;
    ${$self->get_package_symbol('$AUTHORITY')};
}

sub identifier {
    my $self = shift;
    join '-' => (
        $self->name,
        ($self->version   || ()),
        ($self->authority || ()),
    );
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Module - Module Meta Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<meta>

=item B<version>

This is a read-only attribute which returns the C<$VERSION> of the 
package for the given instance.

=item B<authority>

This is a read-only attribute which returns the C<$AUTHORITY> of the 
package for the given instance.

=item B<identifier>

This constructs a string of the name, version and authrity.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

Yuval Kogman E<lt>nothingmuch@woobling.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut