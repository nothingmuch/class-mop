
package Class::MOP::Attribute;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype';

our $VERSION = '0.01';

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize($_[0]) 
}

# NOTE: (meta-circularity)
# This method will be replaces in the 
# boostrap section of Class::MOP, by 
# a new version which uses the 
# &Class::MOP::Class::construct_instance
# method to build an attribute meta-object
# which itself is described with attribute
# meta-objects. 
#     - Ain't meta-circularity grand? :)
sub new {
    my $class   = shift;
    my $name    = shift;
    my %options = @_;    
        
    (defined $name && $name)
        || confess "You must provide a name for the attribute";
    (!exists $options{reader} && !exists $options{writer})
        || confess "You cannot declare an accessor and reader and/or writer functions"
            if exists $options{accessor};
            
    bless {
        name      => $name,
        accessor  => $options{accessor},
        reader    => $options{reader},
        writer    => $options{writer},
        predicate => $options{predicate},
        init_arg  => $options{init_arg},
        default   => $options{default}
    } => $class;
}

sub name { $_[0]->{name} }

sub has_accessor  { defined($_[0]->{accessor})  ? 1 : 0 }
sub has_reader    { defined($_[0]->{reader})    ? 1 : 0 }
sub has_writer    { defined($_[0]->{writer})    ? 1 : 0 }
sub has_predicate { defined($_[0]->{predicate}) ? 1 : 0 }
sub has_init_arg  { defined($_[0]->{init_arg})  ? 1 : 0 }
sub has_default   { defined($_[0]->{default})   ? 1 : 0 }

sub accessor  { $_[0]->{accessor}  } 
sub reader    { $_[0]->{reader}    }
sub writer    { $_[0]->{writer}    }
sub predicate { $_[0]->{predicate} }
sub init_arg  { $_[0]->{init_arg}  }

sub default { 
    my $self = shift;
    if (reftype($self->{default}) && reftype($self->{default}) eq 'CODE') {
        # if the default is a CODE ref, then 
        # we pass in the instance and default
        # can return a value based on that 
        # instance. Somewhat crude, but works.
        return $self->{default}->(shift);
    }           
    $self->{default};
}

{
    # this is just a utility routine to 
    # handle the details of accessors
    my $_inspect_accessor = sub {
        my ($attr_name, $type, $accessor) = @_;
    
        my %ACCESSOR_TEMPLATES = (
            'accessor' => qq{sub {
                \$_[0]->{'$attr_name'} = \$_[1] if scalar(\@_) == 2;
                \$_[0]->{'$attr_name'};
            }},
            'reader' => qq{sub {
                \$_[0]->{'$attr_name'};
            }},
            'writer' => qq{sub {
                \$_[0]->{'$attr_name'} = \$_[1];
            }},
            'predicate' => qq{sub {
                defined \$_[0]->{'$attr_name'} ? 1 : 0;
            }}
        );    
    
        if (reftype($accessor) && reftype($accessor) eq 'HASH') {
            my ($name, $method) = each %{$accessor};
            return ($name, Class::MOP::Attribute::Accessor->wrap($method));        
        }
        else {
            my $method = eval $ACCESSOR_TEMPLATES{$type};
            confess "Could not create the $type for $attr_name CODE(\n" . $ACCESSOR_TEMPLATES{$type} . "\n) : $@" if $@;
            return ($accessor => Class::MOP::Attribute::Accessor->wrap($method));
        }    
    };

    sub install_accessors {
        my ($self, $class) = @_;
        (blessed($class) && $class->isa('Class::MOP::Class'))
            || confess "You must pass a Class::MOP::Class instance (or a subclass)";    
        $class->add_method(
            $_inspect_accessor->($self->name, 'accessor' => $self->accessor())
        ) if $self->has_accessor();

        $class->add_method(            
            $_inspect_accessor->($self->name, 'reader' => $self->reader())
        ) if $self->has_reader();
    
        $class->add_method(
            $_inspect_accessor->($self->name, 'writer' => $self->writer())
        ) if $self->has_writer();
    
        $class->add_method(
            $_inspect_accessor->($self->name, 'predicate' => $self->predicate())
        ) if $self->has_predicate();
        return;
    }
    
}

{
    my $_remove_accessor = sub {
        my ($accessor, $class) = @_;
        if (reftype($accessor) && reftype($accessor) eq 'HASH') {
            ($accessor) = keys %{$accessor};
        }        
        my $method = $class->get_method($accessor);   
        $class->remove_method($accessor) 
            if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
    };
    
    sub remove_accessors {
        my ($self, $class) = @_;
        (blessed($class) && $class->isa('Class::MOP::Class'))
            || confess "You must pass a Class::MOP::Class instance (or a subclass)";    
        $_remove_accessor->($self->accessor(),  $class) if $self->has_accessor();
        $_remove_accessor->($self->reader(),    $class) if $self->has_reader();
        $_remove_accessor->($self->writer(),    $class) if $self->has_writer();
        $_remove_accessor->($self->predicate(), $class) if $self->has_predicate();
        return;                        
    }

}

package Class::MOP::Attribute::Accessor;

use strict;
use warnings;

use Class::MOP::Method;

our $VERSION = '0.01';

our @ISA = ('Class::MOP::Method');

1;

__END__

=pod

=head1 NAME 

Class::MOP::Attribute - Attribute Meta Object

=head1 SYNOPSIS
  
  Class::MOP::Attribute->new('$foo' => (
      accessor  => 'foo',        # dual purpose get/set accessor
      predicate => 'has_foo'     # predicate check for defined-ness      
      init_arg  => '-foo',       # class->new will look for a -foo key
      default   => 'BAR IS BAZ!' # if no -foo key is provided, use this
  ));
  
  Class::MOP::Attribute->new('$.bar' => (
      reader    => 'bar',        # getter
      writer    => 'set_bar',    # setter     
      predicate => 'has_bar'     # predicate check for defined-ness      
      init_arg  => ':bar',       # class->new will look for a :bar key
      # no default value means it is undef
  ));

=head1 DESCRIPTION

The Attribute Protocol is almost entirely an invention of this module,
and is completely optional to this MOP. This is because Perl 5 does not 
have consistent notion of what is an attribute of a class. There are 
so many ways in which this is done, and very few (if any) are 
easily discoverable by this module.

So, all that said, this module attempts to inject some order into this 
chaos, by introducing a consistent API which can be used to create 
object attributes.

=head1 METHODS

=head2 Creation

=over 4

=item B<new ($name, ?%options)>

An attribute must (at the very least), have a C<$name>. All other 
C<%options> are contained added as key-value pairs. Acceptable keys
are as follows:

=over 4

=item I<init_arg>

This should be a string value representing the expected key in 
an initialization hash. For instance, if we have an I<init_arg> 
value of C<-foo>, then the following code will Just Work.

  MyClass->meta->construct_instance(-foo => "Hello There");

=item I<default>

The value of this key is the default value which 
C<Class::MOP::Class::construct_instance> will initialize the 
attribute to. 

B<NOTE:>
If the value is a simple scalar (string or number), then it can 
be just passed as is. However, if you wish to initialize it with 
a HASH or ARRAY ref, then you need to wrap that inside a CODE 
reference, like so:

  Class::MOP::Attribute->new('@foo' => (
      default => sub { [] },
  ));
  
  # or ...  
  
  Class::MOP::Attribute->new('%foo' => (
      default => sub { {} },
  ));  

If you wish to initialize an attribute with a CODE reference 
itself, then you need to wrap that in a subroutine as well, like
so:
  
  Class::MOP::Attribute->new('&foo' => (
      default => sub { sub { print "Hello World" } },
  ));

And lastly, if the value of your attribute is dependent upon 
some other aspect of the instance structure, then you can take 
advantage of the fact that when the I<default> value is a CODE 
reference, it is passed the raw (unblessed) instance structure 
as it's only argument. So you can do things like this:

  Class::MOP::Attribute->new('$object_identity' => (
      default => sub { Scalar::Util::refaddr($_[0]) },
  ));

This last feature is fairly limited as there is no gurantee of 
the order of attribute initializations, so you cannot perform 
any kind of dependent initializations. However, if this is 
something you need, you could subclass B<Class::MOP::Class> and 
this class to acheive it. However, this is currently left as 
an exercise to the reader :).

=back

The I<accessor>, I<reader>, I<writer> and I<predicate> keys can 
contain either; the name of the method and an appropriate default 
one will be generated for you, B<or> a HASH ref containing exactly one 
key (which will be used as the name of the method) and one value, 
which should contain a CODE reference which will be installed as 
the method itself.

=over 4

=item I<accessor>

The I<accessor> is a standard perl-style read/write accessor. It will 
return the value of the attribute, and if a value is passed as an argument, 
it will assign that value to the attribute.

B<NOTE:>
This method will properly handle the following code, by assigning an 
C<undef> value to the attribute.

  $object->set_something(undef);

=item I<reader>

This is a basic read-only accessor, it will just return the value of 
the attribute.

=item I<writer>

This is a basic write accessor, it accepts a single argument, and 
assigns that value to the attribute. This method does not intentially 
return a value, however perl will return the result of the last 
expression in the subroutine, which returns in this returning the 
same value that it was passed. 

B<NOTE:>
This method will properly handle the following code, by assigning an 
C<undef> value to the attribute.

  $object->set_something();

=item I<predicate>

This is a basic test to see if the value of the attribute is not 
C<undef>. It will return true (C<1>) if the attribute's value is 
defined, and false (C<0>) otherwise.

=back

=back 

=head2 Informational

These are all basic read-only value accessors for the values 
passed into C<new>. I think they are pretty much self-explanitory.

=over 4

=item B<name>

=item B<accessor>

=item B<reader>

=item B<writer>

=item B<predicate>

=item B<init_arg>

=item B<default (?$instance)>

As noted in the documentation for C<new> above, if the I<default> 
value is a CODE reference, this accessor will pass a single additional
argument C<$instance> into it and return the value.

=back

=head2 Informational predicates

These are all basic predicate methods for the values passed into C<new>.

=over 4

=item B<has_accessor>

=item B<has_reader>

=item B<has_writer>

=item B<has_predicate>

=item B<has_init_arg>

=item B<has_default>

=back

=head2 Attribute Accessor generation

=over 4

=item B<install_accessors ($class)>

This allows the attribute to generate and install code for it's own 
I<accessor/reader/writer/predicate> methods. This is called by 
C<Class::MOP::Class::add_attribute>.

=item B<remove_accessors ($class)>

This allows the attribute to remove the method for it's own 
I<accessor/reader/writer/predicate>. This is called by 
C<Class::MOP::Class::remove_attribute>.

=back

=head2 Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class.

It should also be noted that B<Class::MOP> will actually bootstrap 
this module by installing a number of attribute meta-objects into 
it's metaclass. This will allow this class to reap all the benifits 
of the MOP when subclassing it. 

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut