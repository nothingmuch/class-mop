
package Class::MOP::Attribute;

use strict;
use warnings;

use Class::MOP::Method::Accessor;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype', 'weaken';

our $VERSION   = '0.19';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

sub meta {
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

# NOTE: (meta-circularity)
# This method will be replaced in the
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
    if(exists $options{builder}){
        confess("builder must be a defined scalar value which is a method name")
            if ref $options{builder} || !(defined $options{builder});
        confess("Setting both default and builder is not allowed.")
            if exists $options{default};
    } else {
        (is_default_a_coderef(\%options))
            || confess("References are not allowed as default values, you must ".
                       "wrap then in a CODE reference (ex: sub { [] } and not [])")
                if exists $options{default} && ref $options{default};
    }
    bless {
        '$!name'      => $name,
        '$!accessor'  => $options{accessor},
        '$!reader'    => $options{reader},
        '$!writer'    => $options{writer},
        '$!predicate' => $options{predicate},
        '$!clearer'   => $options{clearer},
        '$!builder'   => $options{builder},
        '$!init_arg'  => $options{init_arg},
        '$!default'   => $options{default},
        # keep a weakened link to the
        # class we are associated with
        '$!associated_class' => undef,
        # and a list of the methods
        # associated with this attr
        '@!associated_methods' => [],
    } => $class;
}

# NOTE:
# this is a primative (and kludgy) clone operation
# for now, it will be replaced in the Class::MOP
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
    my ($self, $meta_instance, $instance, $params) = @_;
    my $init_arg = $self->{'$!init_arg'};
    # try to fetch the init arg from the %params ...

    # if nothing was in the %params, we can use the
    # attribute's default value (if it has one)
    if(exists $params->{$init_arg}){
        $meta_instance->set_slot_value($instance, $self->name, $params->{$init_arg});
    } 
    elsif (defined $self->{'$!default'}) {
        $meta_instance->set_slot_value($instance, $self->name, $self->default($instance));
    } 
    elsif (defined( my $builder = $self->{'$!builder'})) {
        if ($builder = $instance->can($builder)) {
            $meta_instance->set_slot_value($instance, $self->name, $instance->$builder);
        } 
        else {
            confess(blessed($instance)." does not support builder method '". $self->{'$!builder'} ."' for attribute '" . $self->name . "'");
        }
    }
}

# NOTE:
# the next bunch of methods will get bootstrapped
# away in the Class::MOP bootstrapping section

sub name { $_[0]->{'$!name'} }

sub associated_class   { $_[0]->{'$!associated_class'}   }
sub associated_methods { $_[0]->{'@!associated_methods'} }

sub has_accessor  { defined($_[0]->{'$!accessor'})  ? 1 : 0 }
sub has_reader    { defined($_[0]->{'$!reader'})    ? 1 : 0 }
sub has_writer    { defined($_[0]->{'$!writer'})    ? 1 : 0 }
sub has_predicate { defined($_[0]->{'$!predicate'}) ? 1 : 0 }
sub has_clearer   { defined($_[0]->{'$!clearer'})   ? 1 : 0 }
sub has_builder   { defined($_[0]->{'$!builder'})   ? 1 : 0 }
sub has_init_arg  { defined($_[0]->{'$!init_arg'})  ? 1 : 0 }
sub has_default   { defined($_[0]->{'$!default'})   ? 1 : 0 }

sub accessor  { $_[0]->{'$!accessor'}  }
sub reader    { $_[0]->{'$!reader'}    }
sub writer    { $_[0]->{'$!writer'}    }
sub predicate { $_[0]->{'$!predicate'} }
sub clearer   { $_[0]->{'$!clearer'}   }
sub builder   { $_[0]->{'$!builder'}   }
sub init_arg  { $_[0]->{'$!init_arg'}  }

# end bootstrapped away method section.
# (all methods below here are kept intact)

sub get_read_method  { $_[0]->reader || $_[0]->accessor }
sub get_write_method { $_[0]->writer || $_[0]->accessor }

sub get_read_method_ref {
    my $self = shift;
    if ((my $reader = $self->get_read_method) && $self->associated_class) {   
        return $self->associated_class->get_method($reader);
    }
    else {
        return sub { $self->get_value(@_) };
    }
}

sub get_write_method_ref {
    my $self = shift;    
    if ((my $writer = $self->get_write_method) && $self->associated_class) {    
        return $self->associated_class->get_method($writer);
    }
    else {
        return sub { $self->set_value(@_) };
    }
}

sub is_default_a_coderef {
    ('CODE' eq (reftype($_[0]->{'$!default'} || $_[0]->{default}) || ''))
}

sub default {
    my ($self, $instance) = @_;
    if (defined $instance && $self->is_default_a_coderef) {
        # if the default is a CODE ref, then
        # we pass in the instance and default
        # can return a value based on that
        # instance. Somewhat crude, but works.
        return $self->{'$!default'}->($instance);
    }
    $self->{'$!default'};
}

# slots

sub slots { (shift)->name }

# class association

sub attach_to_class {
    my ($self, $class) = @_;
    (blessed($class) && $class->isa('Class::MOP::Class'))
        || confess "You must pass a Class::MOP::Class instance (or a subclass)";
    weaken($self->{'$!associated_class'} = $class);
}

sub detach_from_class {
    my $self = shift;
    $self->{'$!associated_class'} = undef;
}

# method association

sub associate_method {
    my ($self, $method) = @_;
    push @{$self->{'@!associated_methods'}} => $method;
}

## Slot management

sub set_value {
    my ($self, $instance, $value) = @_;

    Class::MOP::Class->initialize(blessed($instance))
                     ->get_meta_instance
                     ->set_slot_value($instance, $self->name, $value);
}

sub get_value {
    my ($self, $instance) = @_;

    Class::MOP::Class->initialize(blessed($instance))
                     ->get_meta_instance
                     ->get_slot_value($instance, $self->name);
}

sub has_value {
    my ($self, $instance) = @_;

    Class::MOP::Class->initialize(blessed($instance))
                     ->get_meta_instance
                     ->is_slot_initialized($instance, $self->name);
}

sub clear_value {
    my ($self, $instance) = @_;

    Class::MOP::Class->initialize(blessed($instance))
                     ->get_meta_instance
                     ->deinitialize_slot($instance, $self->name);
}

## load em up ...

sub accessor_metaclass { 'Class::MOP::Method::Accessor' }

sub process_accessors {
    my ($self, $type, $accessor, $generate_as_inline_methods) = @_;
    if (reftype($accessor)) {
        (reftype($accessor) eq 'HASH')
            || confess "bad accessor/reader/writer/predicate/clearer format, must be a HASH ref";
        my ($name, $method) = %{$accessor};
        $method = $self->accessor_metaclass->wrap($method);
        $self->associate_method($method);
        return ($name, $method);
    }
    else {
        my $inline_me = ($generate_as_inline_methods && $self->associated_class->instance_metaclass->is_inlinable);
        my $method;
        eval {
            $method = $self->accessor_metaclass->new(
                attribute     => $self,
                is_inline     => $inline_me,
                accessor_type => $type,
            );
        };
        confess "Could not create the '$type' method for " . $self->name . " because : $@" if $@;
        $self->associate_method($method);
        return ($accessor, $method);
    }
}

sub install_accessors {
    my $self   = shift;
    my $inline = shift;
    my $class  = $self->associated_class;

    $class->add_method(
        $self->process_accessors('accessor' => $self->accessor(), $inline)
    ) if $self->has_accessor();

    $class->add_method(
        $self->process_accessors('reader' => $self->reader(), $inline)
    ) if $self->has_reader();

    $class->add_method(
        $self->process_accessors('writer' => $self->writer(), $inline)
    ) if $self->has_writer();

    $class->add_method(
        $self->process_accessors('predicate' => $self->predicate(), $inline)
    ) if $self->has_predicate();

    $class->add_method(
        $self->process_accessors('clearer' => $self->clearer(), $inline)
    ) if $self->has_clearer();

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
            if (blessed($method) && $method->isa('Class::MOP::Method::Accessor'));
    };

    sub remove_accessors {
        my $self = shift;
        # TODO:
        # we really need to make sure to remove from the
        # associates methods here as well. But this is
        # such a slimly used method, I am not worried
        # about it right now.
        $_remove_accessor->($self->accessor(),  $self->associated_class()) if $self->has_accessor();
        $_remove_accessor->($self->reader(),    $self->associated_class()) if $self->has_reader();
        $_remove_accessor->($self->writer(),    $self->associated_class()) if $self->has_writer();
        $_remove_accessor->($self->predicate(), $self->associated_class()) if $self->has_predicate();
        $_remove_accessor->($self->clearer(),   $self->associated_class()) if $self->has_clearer();
        return;
    }

}

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

=item I<builder>

The value of this key is the name of the method that will be
called to obtain the value used to initialize the attribute.
This should be a method in the class associated with the attribute,
not a method in the attribute class itself.

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

The I<accessor>, I<reader>, I<writer>, I<predicate> and I<clearer> keys can
contain either; the name of the method and an appropriate default one will be
generated for you, B<or> a HASH ref containing exactly one key (which will be
used as the name of the method) and one value, which should contain a CODE
reference which will be installed as the method itself.

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

=item I<clearer>

This is the a method that will uninitialize the attr, reverting lazy values
back to their "unfulfilled" state.

=back

=item B<clone (%options)>

=item B<initialize_instance_slot ($instance, $params)>

=back

=head2 Value management

These methods are basically "backdoors" to the instance, which can be used
to bypass the regular accessors, but still stay within the context of the MOP.

These methods are not for general use, and should only be used if you really
know what you are doing.

=over 4

=item B<set_value ($instance, $value)>

Set the value without going through the accessor. Note that this may be done to
even attributes with just read only accessors.

=item B<get_value ($instance)>

Return the value without going through the accessor. Note that this may be done
even to attributes with just write only accessors.

=item B<has_value ($instance)>

Returns a boolean indicating if the item in the C<$instance> has a value in it.
This is basically what the default C<predicate> method calls.

=item B<clear_value ($instance)>

This will clear the value in the C<$instance>. This is basically what the default
C<clearer> would call. Note that this may be done even if the attirbute does not
have any associated read, write or clear methods.

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

=item B<clearer>

=item B<init_arg>

=item B<is_default_a_coderef>

=item B<default (?$instance)>

As noted in the documentation for C<new> above, if the I<default>
value is a CODE reference, this accessor will pass a single additional
argument C<$instance> into it and return the value.

=item B<slots>

Returns a list of slots required by the attribute. This is usually
just one, which is the name of the attribute.

=item B<get_read_method>

=item B<get_write_method>

Return the name of a method name suitable for reading / writing the value 
of the attribute in the associated class. Suitable for use whether 
C<reader> and C<writer> or C<accessor> was used.

=item B<get_read_method_ref>

=item B<get_write_method_ref>

Return the CODE reference of a method suitable for reading / writing the 
value of the attribute in the associated class. Suitable for use whether 
C<reader> and C<writer> or C<accessor> was specified or not.

NOTE: If not reader/writer/accessor was specified, this will use the 
attribute get_value/set_value methods, which can be very inefficient.

=back

=head2 Informational predicates

These are all basic predicate methods for the values passed into C<new>.

=over 4

=item B<has_accessor>

=item B<has_reader>

=item B<has_writer>

=item B<has_predicate>

=item B<has_clearer>

=item B<has_init_arg>

=item B<has_default>

=item B<has_builder>

=back

=head2 Class association

These methods allow you to manage the attributes association with
the class that contains it. These methods should not be used
lightly, nor are they very magical, they are mostly used internally
and by metaclass instances.

=over 4

=item B<associated_class>

This returns the metaclass this attribute is associated with.

=item B<attach_to_class ($class)>

This will store a weaken reference to C<$class> internally. You should
note that just changing the class assocation will not remove the attribute
from it's old class, and initialize it (and it's accessors) in the new
C<$class>. It is up to you to do this manually.

=item B<detach_from_class>

This will remove the weakened reference to the class. It does B<not>
remove the attribute itself from the class (or remove it's accessors),
you must do that yourself if you want too. Actually if that is what
you want to do, you should probably be looking at
L<Class::MOP::Class::remove_attribute> instead.

=back

=head2 Attribute Accessor generation

=over 4

=item B<accessor_metaclass>

Accessors are generated by an accessor metaclass, which is usually
a subclass of C<Class::MOP::Method::Accessor>. This method returns
the name of the accessor metaclass that this attribute uses.

=item B<associate_method ($method)>

This will associate a C<$method> with the given attribute which is
used internally by the accessor generator.

=item B<associated_methods>

This will return the list of methods which have been associated with
the C<associate_method> methods.

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

=item B<remove_accessors>

This allows the attribute to remove the method for it's own
I<accessor/reader/writer/predicate/clearer>. This is called by
C<Class::MOP::Class::remove_attribute>.

NOTE: This does not currently remove methods from the list returned
by C<associated_methods>, that is on the TODO list.

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

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006, 2007 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


