
package Class::MOP::Class::Immutable;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'looks_like_number';

our $VERSION   = '0.02';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Class';

# methods which can *not* be called

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
            my $attr = $metaclass->get_attribute($attr_name);
            $attr->install_accessors(1); # inline the accessors
        }      
    }

    if ($options{inline_constructor}) {       
        $metaclass->add_method(
            $options{constructor_name},
            $class->_generate_inline_constructor(
                \%options, 
                $meta_instance, 
                $metaclass->{'___compute_all_applicable_attributes'}
            )            
        );
    }
          
    bless $metaclass => $class;
}

sub _generate_inline_constructor {
    my ($class, $options, $meta_instance, $attrs) = @_;
    # TODO:
    # the %options should also include a both 
    # a call 'initializer' and call 'SUPER::' 
    # options, which should cover approx 90% 
    # of the possible use cases (even if it 
    # requires some adaption on the part of 
    # the author, after all, nothing is free)
    my $source = 'sub {';
    $source .= "\n" . 'my ($class, %params) = @_;';
    $source .= "\n" . 'my $instance = ' . $meta_instance->inline_create_instance('$class');
    $source .= ";\n" . (join ";\n" => map { 
        $class->_generate_slot_initializer($meta_instance, $attrs, $_) 
    } 0 .. (@$attrs - 1));
    $source .= ";\n" . 'return $instance';
    $source .= ";\n" . '}'; 
    warn $source if $options->{debug};   
    my $code = eval $source;
    confess "Could not eval the constructor :\n\n$source\n\nbecause :\n\n$@" if $@;
    return $code;
}

sub _generate_slot_initializer {
    my ($class, $meta_instance, $attrs, $index) = @_;
    my $attr = $attrs->[$index];
    my $default;
    if ($attr->has_default) {
        if ($attr->is_default_a_coderef) {
            $default = '$attrs->[' . $index . ']->default($instance)';
        }
        else {
            $default = $attrs->[$index]->default;
            unless (looks_like_number($default)) {
                $default = "'$default'";
            }
            # TODO:
            # we should use Data::Dumper to 
            # output any ref's here, obviously 
            # we cannot handle Scalar refs, but
            # it should work for Array and Hash 
            # refs pretty well.
        }
    }
    $meta_instance->inline_set_slot_value(
        '$instance', 
        ("'" . $attr->name . "'"), 
        ('$params{\'' . $attr->init_arg . '\'}' . (defined $default ? (' || ' . $default) : ''))
    )    
}

# cached methods

sub get_meta_instance                 {   (shift)->{'___get_meta_instance'}                  }
sub class_precedence_list             { @{(shift)->{'___class_precedence_list'}}             }
sub compute_all_applicable_attributes { @{(shift)->{'___compute_all_applicable_attributes'}} }
sub get_mutable_metaclass_name        {   (shift)->{'___original_class'}                     }

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

=item B<superclasses>

=back

=head2 Cached methods

=over 4

=item B<class_precedence_list>

=item B<compute_all_applicable_attributes>

=item B<get_meta_instance>

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
