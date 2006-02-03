
package InsideOutClass;

use strict;
use warnings;

use Class::MOP 'meta';

our $VERSION = '0.02';

use Scalar::Util 'refaddr';

use base 'Class::MOP::Class';

sub construct_instance {
    my ($class, %params) = @_;
    # create a scalar ref to use as 
    # the inside-out instance
    my $instance = \(my $var);
    foreach my $attr (map { $_->{attribute} } $class->compute_all_applicable_attributes()) {
        # if the attr has an init_arg, use that, otherwise,
        # use the attributes name itself as the init_arg
        my $init_arg = $attr->has_init_arg() ? $attr->init_arg() : $attr->name;
        # try to fetch the init arg from the %params ...
        my $val;        
        $val = $params{$init_arg} if exists $params{$init_arg};
        # if nothing was in the %params, we can use the 
        # attribute's default value (if it has one)
        $val ||= $attr->default($instance) if $attr->has_default();
        # now add this to the instance structure
        $class->get_package_variable('%' . $attr->name)->{ refaddr($instance) } = $val;
    }    
    return $instance;
}

package InsideOutClass::Attribute;

use strict;
use warnings;

use Class::MOP 'meta';

our $VERSION = '0.02';

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype', 'refaddr';

use base 'Class::MOP::Attribute';

{
    # this is just a utility routine to 
    # handle the details of accessors
    my $_inspect_accessor = sub {
        my ($attr_name, $type, $accessor) = @_;    
        my %ACCESSOR_TEMPLATES = (
            'accessor' => 'sub {
                $' . $attr_name . '{ refaddr($_[0]) } = $_[1] if scalar(@_) == 2;
                $' . $attr_name . '{ refaddr($_[0]) };
            }',
            'reader' => 'sub {
                $' . $attr_name . '{ refaddr($_[0]) };
            }',
            'writer' => 'sub {
                $' . $attr_name . '{ refaddr($_[0]) } = $_[1];
            }',
            'predicate' => 'sub {
                defined($' . $attr_name . '{ refaddr($_[0]) }) ? 1 : 0;
            }'
        );    
    
        my $method = eval $ACCESSOR_TEMPLATES{$type};
        confess "Could not create the $type for $attr_name CODE(\n" . $ACCESSOR_TEMPLATES{$type} . "\n) : $@" if $@;
        return ($accessor => Class::MOP::Attribute::Accessor->wrap($method));
    };

    sub install_accessors {
        my ($self, $class) = @_;
        (blessed($class) && $class->isa('Class::MOP::Class'))
            || confess "You must pass a Class::MOP::Class instance (or a subclass)";       
        
        # create the package variable to 
        # store the inside out attribute
        $class->add_package_variable('%' . $self->name);
        
        # now create the accessor/reader/writer/predicate methods
             
        $class->add_method(
            $_inspect_accessor->($class->name . '::' . $self->name, 'accessor' => $self->accessor())
        ) if $self->has_accessor();

        $class->add_method(            
            $_inspect_accessor->($class->name . '::' . $self->name, 'reader' => $self->reader())
        ) if $self->has_reader();
    
        $class->add_method(
            $_inspect_accessor->($class->name . '::' . $self->name, 'writer' => $self->writer())
        ) if $self->has_writer();
    
        $class->add_method(
            $_inspect_accessor->($class->name . '::' . $self->name, 'predicate' => $self->predicate())
        ) if $self->has_predicate();
        return;
    }
    
}

## &remove_attribute is left as an exercise for the reader :)

1;

__END__

=pod

=head1 NAME

InsideOutClass - A set of metaclasses which use the Inside-Out technique

=head1 SYNOPSIS

  package Foo;
  
  sub meta { InsideOutClass->initialize($_[0]) }
  
  __PACKAGE__->meta->add_attribute(
      InsideOutClass::Attribute->new('foo' => (
          reader => 'get_foo',
          writer => 'set_foo'
      ))
  );    
  
  sub new  {
      my $class = shift;
      bless $class->meta->construct_instance() => $class;
  }  

  # now you can just use the class as normal

=head1 DESCRIPTION

This is a set of example metaclasses which implement the Inside-Out 
class technique. What follows is a brief explaination of the code 
found in this module.

First step is to subclass B<Class::MOP::Class> and override the 
C<construct_instance> method. The default C<construct_instance> 
will create a HASH reference using the parameters and attribute 
default values. Since inside-out objects don't use HASH refs, and 
use package variables instead, we need to write code to handle 
this difference. 

The next step is to create the subclass of B<Class::MOP::Attribute> 
and override the C<install_accessors> method (you would also need to
override the C<remove_accessors> too, but we can safely ignore that 
in our example). The C<install_accessor> method is called by the 
C<add_attribute> method of B<Class::MOP::Class>, and will install 
the accessors for your attribute. Since inside-out objects require 
different types of accessors, we need to write the code to handle 
this difference as well.

And that is pretty much all. Of course I am ignoring need for 
inside-out objects to be C<DESTROY>-ed, and some other details as 
well, but this is an example. A real implementation is left as an 
exercise to the reader.

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
