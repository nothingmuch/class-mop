
package Class::MOP::Method::Generated;

use strict;
use warnings;

use Carp 'confess';

our $VERSION   = '0.63';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method';

sub new {
    my $class   = shift;
    my %options = @_;  
        
    ($options{package_name} && $options{name})
        || confess "You must supply the package_name and name parameters $Class::MOP::Method::UPGRADE_ERROR_TEXT";     
        
    my $self = bless {
        # from our superclass
        '&!body'          => undef,
        '$!package_name'  => $options{package_name},
        '$!name'          => $options{name},        
        # specific to this subclass
        '$!is_inline'     => ($options{is_inline} || 0),
    } => $class;
    
    $self->initialize_body;
    
    return $self;
}

## accessors

sub is_inline { (shift)->{'$!is_inline'} }

sub initialize_body {
    confess "No body to initialize, " . __PACKAGE__ . " is an abstract base class";
}



1;

__END__

=pod

=head1 NAME 

Class::MOP::Method::Generated - Abstract base class for generated methods

=head1 DESCRIPTION

This is a C<Class::MOP::Method> subclass which is used interally 
by C<Class::MOP::Method::Accessor> and C<Class::MOP::Method::Constructor>.

=head1 METHODS

=over 4

=item B<new (%options)>

This creates the method based on the criteria in C<%options>, 
these options are:

=over 4

=item I<is_inline>

This is a boolean to indicate if the method should be generated
as a closure, or as a more optimized inline version.

=back

=item B<is_inline>

This returns the boolean which was passed into C<new>.

=item B<initialize_body>

This is an abstract method and will throw an exception if called.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

