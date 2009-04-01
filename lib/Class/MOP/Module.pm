
package Class::MOP::Module;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.80';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Package';

sub version {  
    my $self = shift;
    ${$self->get_package_symbol({ sigil => '$', type => 'SCALAR', name => 'VERSION' })};
}

sub authority {  
    my $self = shift;
    ${$self->get_package_symbol({ sigil => '$', type => 'SCALAR', name => 'AUTHORITY' })};
}

sub identifier {
    my $self = shift;
    join '-' => (
        $self->name,
        ($self->version   || ()),
        ($self->authority || ()),
    );
}

sub create {
    my ( $class, %options ) = @_;

    my $package_name = $options{package};

    (defined $package_name && $package_name)
        || confess "You must pass a package name";

    my $code = "package $package_name;";
    $code .= "\$$package_name\:\:VERSION = '" . $options{version} . "';"
        if exists $options{version};
    $code .= "\$$package_name\:\:AUTHORITY = '" . $options{authority} . "';"
        if exists $options{authority};

    eval $code;
    confess "creation of $package_name failed : $@" if $@;

    return; # XXX: should this return some kind of meta object? ~sartak
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Module - Module Meta Object

=head1 DESCRIPTION

A module is essentially a L<Class::MOP::Package> with metadata, in our
case the version and authority.

=head1 INHERITANCE

B<Class::MOP::Module> is a subclass of L<Class::MOP::Package>.

=head1 METHODS

=over 4

=item B<< $metamodule->version >>

This is a read-only attribute which returns the C<$VERSION> of the
package, if one exists.

=item B<< $metamodule->authority >>

This is a read-only attribute which returns the C<$AUTHORITY> of the
package, if one exists.

=item B<< $metamodule->identifier >>

This constructs a string which combines the name, version and
authority.

=item B<< Class::MOP::Module->meta >>

This will return a L<Class::MOP::Class> instance for this class.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
