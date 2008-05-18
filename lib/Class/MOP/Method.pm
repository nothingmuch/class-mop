
package Class::MOP::Method;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'reftype', 'blessed';

our $VERSION   = '0.06';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

# NOTE:
# if poked in the right way, 
# they should act like CODE refs.
use overload '&{}' => sub { $_[0]->body }, fallback => 1;

# construction

sub wrap { 
    my ( $class, $code, %params ) = @_;

    ('CODE' eq (reftype($code) || ''))
        || confess "You must supply a CODE reference to bless, not (" . ($code || 'undef') . ")";
    bless { 
        '&!body' => $code,
        '$!package_name' => $params{package_name} || (Class::MOP::get_code_info($code))[0],
        '$!name' => $params{name} || (Class::MOP::get_code_info($code))[1],
    } => blessed($class) || $class;
}

## accessors

sub body { (shift)->{'&!body'} }

# TODO - add associated_class

# informational

# NOTE: 
# this may not be the same name 
# as the class you got it from
# This is the package stash name 
# associated with the actual CODE-ref
# meaning the package it was defined in
sub package_name {
    (shift)->{'$!package_name'};
}

# NOTE: 
# this may not be the same name 
# as the method name it is stored
# with. This gets the name associated
# with the actual CODE-ref
sub name { 
    (shift)->{'$!name'};
}

sub fully_qualified_name {
	my $code = shift;
	$code->package_name . '::' . $code->name;		
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Method - Method Meta Object

=head1 DESCRIPTION

The Method Protocol is very small, since methods in Perl 5 are just 
subroutines within the particular package. We provide a very basic 
introspection interface.

=head1 METHODS

=head2 Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class.

=back

=head2 Construction

=over 4

=item B<wrap ($code)>

This is the basic constructor, it returns a B<Class::MOP::Method> 
instance which wraps the given C<$code> reference.

=back

=head2 Informational

=over 4

=item B<body>

This returns the actual CODE reference of the particular instance.

=item B<name>

This returns the name of the CODE reference.

=item B<package_name>

This returns the package name that the CODE reference is attached to.

=item B<fully_qualified_name>

This returns the fully qualified name of the CODE reference.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

