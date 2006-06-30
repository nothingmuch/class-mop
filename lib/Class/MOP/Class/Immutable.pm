
package Class::MOP::Class::Immutable;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION = '0.01';

use base 'Class::MOP::Class';

# methods which can *not* be called

sub reinitialize { confess 'Cannot call method "reinitialize" on an immutable instance' }

sub add_method    { confess 'Cannot call method "add_method" on an immutable instance'    }
sub alias_method  { confess 'Cannot call method "alias_method" on an immutable instance'  }
sub remove_method { confess 'Cannot call method "remove_method" on an immutable instance' }

sub add_attribute    { confess 'Cannot call method "add_attribute" on an immutable instance'    }
sub remove_attribute { confess 'Cannot call method "remove_attribute" on an immutable instance' }

sub add_package_symbol    { confess 'Cannot call method "add_package_symbol" on an immutable instance'    }
sub remove_package_symbol { confess 'Cannot call method "remove_package_symbol" on an immutable instance' }

# NOTE:
# superclasses is an accessor, so 
# it just cannot be changed
sub superclasses {
    my $class = shift;
    (!@_) || confess 'Cannot change the "superclasses" on an immmutable instance';
    no strict 'refs';
    @{$class->name . '::ISA'};    
}

# predicates

sub is_mutable   { 0 }
sub is_immutable { 1 }

sub make_immutable { () }

sub make_metaclass_immutable {
    my ($class, $metaclass) = @_;
    $metaclass->{'___class_precedence_list'} = [ $metaclass->class_precedence_list ];
    $metaclass->{'___get_meta_instance'} = $metaclass->get_meta_instance;    
    $metaclass->{'___compute_all_applicable_attributes'} = [ $metaclass->compute_all_applicable_attributes ];       
    $metaclass->{'___original_class'} = blessed($metaclass);           
    bless $metaclass => $class;
}

# cached methods

sub get_meta_instance { (shift)->{'___get_meta_instance'} }

sub class_precedence_list { 
    @{ (shift)->{'___class_precedence_list'} } 
}

sub compute_all_applicable_attributes {
    @{ (shift)->{'___compute_all_applicable_attributes'} }
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Class::Immutable - An immutable version of Class::MOP::Class

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class.

=back

=head2 Methods which will die if you touch them.

=over 4

=item B<add_attribute>

=item B<add_method>

=item B<add_package_symbol>

=item B<alias_method>

=item B<reinitialize>

=item B<remove_attribute>

=item B<remove_method>

=item B<remove_package_symbol>

=item B<superclasses>

=back

=head2 Cached methods

=over 4

=item B<class_precedence_list>

=item B<compute_all_applicable_attributes>

=item B<get_meta_instance>

=back

=head2 Introspection and Construction

=over 4

=item B<is_immutable>

=item B<is_mutable>

=item B<make_immutable>

=item B<make_metaclass_immutable>

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
