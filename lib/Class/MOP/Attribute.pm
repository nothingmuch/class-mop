
package Class::MOP::Attribute;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype', 'weaken';

our $VERSION = '0.07';

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
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
    $options{init_arg} = $name 
        if not exists $options{init_arg};
            
    bless {
        name      => $name,
        accessor  => $options{accessor},
        reader    => $options{reader},
        writer    => $options{writer},
        predicate => $options{predicate},
        init_arg  => $options{init_arg},
        default   => $options{default},
        # keep a weakened link to the 
        # class we are associated with
        associated_class => undef,
    } => $class;
}

# NOTE:
# this is a primative (and kludgy) clone operation 
# for now, it will be repleace in the Class::MOP
# bootstrap with a proper one, however we know 
# that this one will work fine for now.
sub clone {
    my $self    = shift;
    my %options = @_;
    (blessed($self))
        || confess "Can only clone an instance";
    return bless { %{$self}, %options } => blessed($self);
}

sub initialize_instance_slot {
    my ($self, $class, $instance, $params) = @_;
    my $init_arg = $self->{init_arg};
    # try to fetch the init arg from the %params ...
    my $val;        
    $val = $params->{$init_arg} if exists $params->{$init_arg};
    # if nothing was in the %params, we can use the 
    # attribute's default value (if it has one)
    if (!defined $val && defined $self->{default}) {
        $val = $self->default($instance); 
    }            
    $instance->{$self->name} = $val;    
}

# NOTE:
# the next bunch of methods will get bootstrapped 
# away in the Class::MOP bootstrapping section

sub name { $_[0]->{name} }

sub associated_class { $_[0]->{associated_class} }

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

# end bootstrapped away method section.
# (all methods below here are kept intact)

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

# class association 

sub attach_to_class {
    my ($self, $class) = @_;
    (blessed($class) && $class->isa('Class::MOP::Class'))
        || confess "You must pass a Class::MOP::Class instance (or a subclass)";
    weaken($self->{associated_class} = $class);    
}

sub detach_from_class {
    my $self = shift;
    $self->{associated_class} = undef;        
}

## Method generation helpers

sub generate_accessor_method {
    my ($self, $attr_name) = @_;
    sub {
        $_[0]->{$attr_name} = $_[1] if scalar(@_) == 2;
        $_[0]->{$attr_name};
    };
}

sub generate_reader_method {
    my ($self, $attr_name) = @_; 
    sub { 
        confess "Cannot assign a value to a read-only accessor" if @_ > 1;
        $_[0]->{$attr_name}; 
    };   
}

sub generate_writer_method {
    my ($self, $attr_name) = @_; 
    sub { $_[0]->{$attr_name} = $_[1] };
}

sub generate_predicate_method {
    my ($self, $attr_name) = @_; 
    sub { defined $_[0]->{$attr_name} ? 1 : 0 };
}

sub process_accessors {
    my ($self, $type, $accessor) = @_;
    if (reftype($accessor)) {
        (reftype($accessor) eq 'HASH')
            || confess "bad accessor/reader/writer/predicate format, must be a HASH ref";
        my ($name, $method) = each %{$accessor};
        return ($name, Class::MOP::Attribute::Accessor->wrap($method));        
    }
    else {
        my $generator = $self->can('generate_' . $type . '_method');
        ($generator)
            || confess "There is no method generator for the type='$type'";
        if (my $method = $self->$generator($self->name)) {
            return ($accessor => Class::MOP::Attribute::Accessor->wrap($method));            
        }
        confess "Could not create the '$type' method for " . $self->name . " because : $@";
    }    
}

sub install_accessors {
    my $self  = shift;
    my $class = $self->associated_class;
    
    $class->add_method(
        $self->process_accessors('accessor' => $self->accessor())
    ) if $self->has_accessor();

    $class->add_method(            
        $self->process_accessors('reader' => $self->reader())
    ) if $self->has_reader();

    $class->add_method(
        $self->process_accessors('writer' => $self->writer())
    ) if $self->has_writer();

    $class->add_method(
        $self->process_accessors('predicate' => $self->predicate())
    ) if $self->has_predicate();
    return;
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
        my $self = shift;
        $_remove_accessor->($self->accessor(),  $self->associated_class()) if $self->has_accessor();
        $_remove_accessor->($self->reader(),    $self->associated_class()) if $self->has_reader();
        $_remove_accessor->($self->writer(),    $self->associated_class()) if $self->has_writer();
        $_remove_accessor->($self->predicate(), $self->associated_class()) if $self->has_predicate();
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

In an init_arg is not assigned, it will automatically use the 
value of C<$name>.

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

=item B<clone (%options)>

=item B<initialize_instance_slot ($instance, $params)>

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

=head2 Class association

=over 4

=item B<associated_class>

=item B<attach_to_class ($class)>

=item B<detach_from_class>

=back

=head2 Attribute Accessor generation

=over 4

=item B<install_accessors>

This allows the attribute to generate and install code for it's own 
I<accessor/reader/writer/predicate> methods. This is called by 
C<Class::MOP::Class::add_attribute>.

This method will call C<process_accessors> for each of the possible 
method types (accessor, reader, writer & predicate).

=item B<process_accessors ($type, $value)>

This takes a C<$type> (accessor, reader, writer or predicate), and 
a C<$value> (the value passed into the constructor for each of the
different types). It will then either generate the method itself 
(using the C<generate_*_method> methods listed below) or it will 
use the custom method passed through the constructor. 

=over 4

=item B<generate_accessor_method ($attr_name)>

=item B<generate_predicate_method ($attr_name)>

=item B<generate_reader_method ($attr_name)>

=item B<generate_writer_method ($attr_name)>

=back

=item B<remove_accessors>

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