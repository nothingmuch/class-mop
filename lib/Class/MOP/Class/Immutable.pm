
package Class::MOP::Class::Immutable;

use strict;
use warnings;

use Class::MOP::Method::Constructor;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.04';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Class';

# enforce the meta-circularity here
# and hide the Immutable part

sub meta { 
    my $self = shift;
    # if it is not blessed, then someone is asking 
    # for the meta of Class::MOP::Class::Immutable
    return Class::MOP::Class->initialize($self) unless blessed($self);
    # otherwise, they are asking for the metaclass 
    # which has been made immutable, which is itself
    return $self;
}

# methods which can *not* be called
for my $meth (qw(
    add_method
    alias_method
    remove_method
    add_attribute
    remove_attribute
    add_package_symbol
    remove_package_symbol
)) {
    no strict 'refs';
    *{$meth} = sub {
        confess "Cannot call method '$meth' on an immutable instance";
    };
}

# NOTE:
# superclasses is an accessor, so 
# it just cannot be changed
sub superclasses {
    my $class = shift;
    (!@_) || confess 'Cannot change the "superclasses" on an immmutable instance';
    @{$class->get_package_symbol('@ISA')};    
}

# predicates

sub is_mutable   { 0 }
sub is_immutable { 1 }

sub make_immutable { () }

sub make_metaclass_immutable {
    my ($class, $metaclass, %options) = @_;
    
    # NOTE:
    # i really need the // (defined-or) operator here
    $options{inline_accessors}   = 1     unless exists $options{inline_accessors};
    $options{inline_constructor} = 1     unless exists $options{inline_constructor};
    $options{constructor_name}   = 'new' unless exists $options{constructor_name};
    $options{debug}              = 0     unless exists $options{debug};
    
    my $meta_instance = $metaclass->get_meta_instance;
    $metaclass->{'___class_precedence_list'}             = [ $metaclass->class_precedence_list ];
    $metaclass->{'___compute_all_applicable_attributes'} = [ $metaclass->compute_all_applicable_attributes ];           
    $metaclass->{'___get_meta_instance'}                 = $meta_instance;    
    $metaclass->{'___original_class'}                    = blessed($metaclass);     
          
    if ($options{inline_accessors}) {
        foreach my $attr_name ($metaclass->get_attribute_list) {
            # inline the accessors
            $metaclass->get_attribute($attr_name)
                      ->install_accessors(1); 
        }      
    }

    if ($options{inline_constructor}) {       
        my $constructor_class = $options{constructor_class} || 'Class::MOP::Method::Constructor';
        $metaclass->add_method(
            $options{constructor_name},
            $constructor_class->new(
                options       => \%options, 
                meta_instance => $meta_instance, 
                attributes    => $metaclass->{'___compute_all_applicable_attributes'}                
            )
        );
    }
    
    # now cache the method map ...
    $metaclass->{'___get_method_map'} = $metaclass->get_method_map;
          
    bless $metaclass => $class;
}

# cached methods

sub get_meta_instance                 {   (shift)->{'___get_meta_instance'}                  }
sub class_precedence_list             { @{(shift)->{'___class_precedence_list'}}             }
sub compute_all_applicable_attributes { @{(shift)->{'___compute_all_applicable_attributes'}} }
sub get_mutable_metaclass_name        {   (shift)->{'___original_class'}                     }
sub get_method_map                    {   (shift)->{'___get_method_map'}                     }

1;

__END__

=pod

=head1 NAME 

Class::MOP::Class::Immutable - An immutable version of Class::MOP::Class

=head1 SYNOPSIS

  package Point;
  use metaclass;
  
  __PACKAGE__->meta->add_attribute('x' => (accessor => 'x', default => 10));
  __PACKAGE__->meta->add_attribute('y' => (accessor => 'y'));
  
  sub new {
      my $class = shift;
      $class->meta->new_object(@_);
  }
  
  sub clear {
      my $self = shift;
      $self->x(0);
      $self->y(0);    
  }
  
  __PACKAGE__->meta->make_immutable();  # close the class

=head1 DESCRIPTION

Class::MOP offers many benefits to object oriented development but it 
comes at a cost. Pure Class::MOP classes can be quite a bit slower than 
the typical hand coded Perl classes. This is because just about 
I<everything> is recalculated on the fly, and nothing is cached. The 
reason this is so, is because Perl itself allows you to modify virtually
everything at runtime. Class::MOP::Class::Immutable offers an alternative 
to this.

By making your class immutable, you are promising that you will not 
modify your inheritence tree or the attributes of any classes in 
that tree. Since runtime modifications like this are fairly atypical
(and usually recomended against), this is not usally a very hard promise 
to make. For making this promise you are given a wide range of 
optimization options which bring speed close to (and sometimes above) 
those of typical hand coded Perl. 

=head1 METHODS

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class.

=back

=head2 Introspection and Construction

=over 4

=item B<make_metaclass_immutable>

The arguments to C<Class::MOP::Class::make_immutable> are passed 
to this method, which 

=over 4

=item I<inline_accessors (Bool)>

=item I<inline_constructor (Bool)>

=item I<debug (Bool)>

=item I<constructor_name (Str)>

=back

=item B<is_immutable>

=item B<is_mutable>

=item B<make_immutable>

=item B<get_mutable_metaclass_name>

=back

=head2 Methods which will die if you touch them.

=over 4

=item B<add_attribute>

=item B<add_method>

=item B<add_package_symbol>

=item B<alias_method>

=item B<remove_attribute>

=item B<remove_method>

=item B<remove_package_symbol>

=back

=head2 Methods which work slightly differently.

=over 4

=item B<superclasses>

This method becomes read-only in an immutable class.

=back

=head2 Cached methods

=over 4

=item B<class_precedence_list>

=item B<compute_all_applicable_attributes>

=item B<get_meta_instance>

=item B<get_method_map>

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
