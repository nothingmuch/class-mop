
package Class::MOP::Module;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.71';
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

This is an abstraction of a Perl 5 module, it is a superclass of
L<Class::MOP::Class>. A module essentially a package with metadata, 
in our case the version and authority. 

=head1 METHODS

=over 4

=item B<meta>

Returns a metaclass for this package.

=item B<initialize ($package_name)>

This will initialize a Class::MOP::Module instance which represents 
the module of C<$package_name>.

=item B<version>

This is a read-only attribute which returns the C<$VERSION> of the 
package for the given instance.

=item B<authority>

This is a read-only attribute which returns the C<$AUTHORITY> of the 
package for the given instance.

=item B<identifier>

This constructs a string of the name, version and authority.

=item B<create>

This creates the module; it does not return a useful result.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
