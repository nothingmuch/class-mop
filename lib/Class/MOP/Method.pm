
package Class::MOP::Method;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.63';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

# NOTE:
# if poked in the right way,
# they should act like CODE refs.
use overload '&{}' => sub { $_[0]->body }, fallback => 1;

our $UPGRADE_ERROR_TEXT = q{
---------------------------------------------------------
NOTE: this error is likely not an error, but a regression
caused by the latest upgrade to Moose/Class::MOP. Consider
upgrading any MooseX::* modules to their latest versions
before spending too much time chasing this one down.
---------------------------------------------------------
};

# construction

sub wrap {
    my ( $class, $code, %params ) = @_;

    ('CODE' eq ref($code))
        || confess "You must supply a CODE reference to bless, not (" . ($code || 'undef') . ")";

    ($params{package_name} && $params{name})
        || confess "You must supply the package_name and name parameters $UPGRADE_ERROR_TEXT";

    bless {
        '&!body'         => $code,
        '$!package_name' => $params{package_name},
        '$!name'         => $params{name},
    } => blessed($class) || $class;
}

## accessors

sub body { (shift)->{'&!body'} }

# TODO - add associated_class

# informational

sub package_name {
    my $self = shift;
    $self->{'$!package_name'} ||= (Class::MOP::get_code_info($self->body))[0];
}

sub name {
    my $self = shift;
    $self->{'$!name'} ||= (Class::MOP::get_code_info($self->body))[1];
}

sub fully_qualified_name {
    my $code = shift;
    $code->package_name . '::' . $code->name;
}

# NOTE:
# the Class::MOP bootstrap
# will create this for us
# - SL
# sub clone { ... }

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

=item B<wrap ($code, %params)>

This is the basic constructor, it returns a B<Class::MOP::Method>
instance which wraps the given C<$code> reference. You can also
set the C<package_name> and C<name> attributes using the C<%params>.
If these are not set, then thier accessors will attempt to figure
it out using the C<Class::MOP::get_code_info> function.

=item B<clone (%params)>

This will make a copy of the object, allowing you to override
any values by stuffing them in C<%params>.

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

