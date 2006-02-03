
package Class::MOP::Class;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype';
use Sub::Name    'subname';
use B            'svref_2object';

our $VERSION = '0.02';

# Self-introspection

sub meta { $_[0]->initialize($_[0]) }

# Creation

{
    # Metaclasses are singletons, so we cache them here.
    # there is no need to worry about destruction though
    # because they should die only when the program dies.
    # After all, do package definitions even get reaped?
    my %METAS;
    sub initialize {
        my $class        = shift;
        my $package_name = shift;
        (defined $package_name && $package_name)
            || confess "You must pass a package name";        
        return $METAS{$package_name} if exists $METAS{$package_name};
        $METAS{$package_name} = $class->construct_class_instance($package_name, @_);
    }
    
    # NOTE: (meta-circularity) 
    # this is a special form of &construct_instance 
    # (see below), which is used to construct class
    # meta-object instances for any Class::MOP::* 
    # class. All other classes will use the more 
    # normal &construct_instance.
    sub construct_class_instance {
        my $class        = shift;
        my $package_name = shift;
        (defined $package_name && $package_name)
            || confess "You must pass a package name";    
        $class = blessed($class) || $class;
        if ($class =~ /^Class::MOP::/) {    
            bless { 
                '$:package'             => $package_name, 
                '%:attributes'          => {},
                '$:attribute_metaclass' => 'Class::MOP::Attribute',
                '$:method_metaclass'    => 'Class::MOP::Method',                
            } => $class;
        }
        else {
            bless $class->meta->construct_instance(':package' => $package_name, @_) => $class
        }
    }
}

sub create {
    my ($class, $package_name, $package_version, %options) = @_;
    (defined $package_name && $package_name)
        || confess "You must pass a package name";
    my $code = "package $package_name;";
    $code .= "\$$package_name\:\:VERSION = '$package_version';" 
        if defined $package_version;
    eval $code;
    confess "creation of $package_name failed : $@" if $@;    
    my $meta = $class->initialize($package_name);
    $meta->superclasses(@{$options{superclasses}})
        if exists $options{superclasses};
    # NOTE:
    # process attributes first, so that they can 
    # install accessors, but locally defined methods
    # can then overwrite them. It is maybe a little odd, but
    # I think this should be the order of things.
    if (exists $options{attributes}) {
        foreach my $attr (@{$options{attributes}}) {
            $meta->add_attribute($attr);
        }
    }        
    if (exists $options{methods}) {
        foreach my $method_name (keys %{$options{methods}}) {
            $meta->add_method($method_name, $options{methods}->{$method_name});
        }
    }  
    return $meta;
}

# Instance Construction

sub construct_instance {
    my ($class, %params) = @_;
    my $instance = {};
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
        $instance->{$attr->name} = $val;
    }
    return $instance;
}

# Informational 

sub name { $_[0]->{'$:package'} }

sub version {  
    my $self = shift;
    no strict 'refs';
    ${$self->name . '::VERSION'};
}

# Inheritance

sub superclasses {
    my $self = shift;
    no strict 'refs';
    if (@_) {
        my @supers = @_;
        @{$self->name . '::ISA'} = @supers;
    }
    @{$self->name . '::ISA'};        
}

sub class_precedence_list {
    my $self = shift;
    # NOTE:
    # We need to check for ciruclar inheirtance here.
    # This will do nothing if all is well, and blow
    # up otherwise. Yes, it's an ugly hack, better 
    # suggestions are welcome.
    { $self->name->isa('This is a test for circular inheritance') }
    # ... and no back to our regularly scheduled program
    (
        $self->name, 
        map { 
            $self->initialize($_)->class_precedence_list()
        } $self->superclasses()
    );   
}

## Methods

# un-used right now ...
sub method_metaclass { $_[0]->{'$:method_metaclass'} }

sub add_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";
    # use reftype here to allow for blessed subs ...
    (reftype($method) && reftype($method) eq 'CODE')
        || confess "Your code block must be a CODE reference";
    my $full_method_name = ($self->name . '::' . $method_name);    
        
    no strict 'refs';
    no warnings 'redefine';
    *{$full_method_name} = subname $full_method_name => $method;
}

{

    ## private utility functions for has_method
    my $_find_subroutine_package_name = sub { eval { svref_2object($_[0])->GV->STASH->NAME } || '' };
    my $_find_subroutine_name         = sub { eval { svref_2object($_[0])->GV->NAME        } || '' };

    sub has_method {
        my ($self, $method_name) = @_;
        (defined $method_name && $method_name)
            || confess "You must define a method name";    
    
        my $sub_name = ($self->name . '::' . $method_name);    
        
        no strict 'refs';
        return 0 if !defined(&{$sub_name});        
        return 0 if $_find_subroutine_package_name->(\&{$sub_name}) ne $self->name &&
                    $_find_subroutine_name->(\&{$sub_name})         ne '__ANON__';
        return 1;
    }

}

sub get_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    no strict 'refs';    
    return \&{$self->name . '::' . $method_name} 
        if $self->has_method($method_name);   
    return; # <- make sure to return undef
}

sub remove_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";
    
    my $removed_method = $self->get_method($method_name);    
    
    no strict 'refs';
    delete ${$self->name . '::'}{$method_name}
        if defined $removed_method;
        
    return $removed_method;
}

sub get_method_list {
    my $self = shift;
    no strict 'refs';
    grep { $self->has_method($_) } %{$self->name . '::'};
}

sub compute_all_applicable_methods {
    my $self = shift;
    my @methods;
    # keep a record of what we have seen
    # here, this will handle all the 
    # inheritence issues because we are 
    # using the &class_precedence_list
    my (%seen_class, %seen_method);
    foreach my $class ($self->class_precedence_list()) {
        next if $seen_class{$class};
        $seen_class{$class}++;
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        foreach my $method_name ($meta->get_method_list()) { 
            next if exists $seen_method{$method_name};
            $seen_method{$method_name}++;
            push @methods => {
                name  => $method_name, 
                class => $class,
                code  => $meta->get_method($method_name)
            };
        }
    }
    return @methods;
}

sub find_all_methods_by_name {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name to find";    
    my @methods;
    # keep a record of what we have seen
    # here, this will handle all the 
    # inheritence issues because we are 
    # using the &class_precedence_list
    my %seen_class;
    foreach my $class ($self->class_precedence_list()) {
        next if $seen_class{$class};
        $seen_class{$class}++;
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        push @methods => {
            name  => $method_name, 
            class => $class,
            code  => $meta->get_method($method_name)
        } if $meta->has_method($method_name);
    }
    return @methods;

}

## Attributes

sub attribute_metaclass { $_[0]->{'$:attribute_metaclass'} }

sub add_attribute {
    my $self      = shift;
    # either we have an attribute object already
    # or we need to create one from the args provided
    my $attribute = blessed($_[0]) ? $_[0] : $self->attribute_metaclass->new(@_);
    # make sure it is derived from the correct type though
    ($attribute->isa('Class::MOP::Attribute'))
        || confess "Your attribute must be an instance of Class::MOP::Attribute (or a subclass)";    
    $attribute->attach_to_class($self);
    $attribute->install_accessors();        
    $self->{'%:attrs'}->{$attribute->name} = $attribute;
}

sub has_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    exists $self->{'%:attrs'}->{$attribute_name} ? 1 : 0;    
} 

sub get_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    return $self->{'%:attrs'}->{$attribute_name} 
        if $self->has_attribute($attribute_name);    
} 

sub remove_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    my $removed_attribute = $self->{'%:attrs'}->{$attribute_name};    
    delete $self->{'%:attrs'}->{$attribute_name} 
        if defined $removed_attribute;        
    $removed_attribute->remove_accessors();        
    $removed_attribute->detach_from_class();    
    return $removed_attribute;
} 

sub get_attribute_list {
    my $self = shift;
    keys %{$self->{'%:attrs'}};
} 

sub compute_all_applicable_attributes {
    my $self = shift;
    my @attrs;
    # keep a record of what we have seen
    # here, this will handle all the 
    # inheritence issues because we are 
    # using the &class_precedence_list
    my (%seen_class, %seen_attr);
    foreach my $class ($self->class_precedence_list()) {
        next if $seen_class{$class};
        $seen_class{$class}++;
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        foreach my $attr_name ($meta->get_attribute_list()) { 
            next if exists $seen_attr{$attr_name};
            $seen_attr{$attr_name}++;
            push @attrs => {
                name      => $attr_name, 
                class     => $class,
                attribute => $meta->get_attribute($attr_name)
            };
        }
    }
    return @attrs;    
}

# Class attributes

sub add_package_variable {
    my ($self, $variable, $initial_value) = @_;
    (defined $variable && $variable =~ /^[\$\@\%]/)
        || confess "variable name does not have a sigil";
    
    my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    if (defined $initial_value) {
        no strict 'refs';
        *{$self->name . '::' . $name} = $initial_value;
    }
    else {
        eval $sigil . $self->name . '::' . $name;
        confess "Could not create package variable ($variable) because : $@" if $@;
    }
}

sub has_package_variable {
    my ($self, $variable) = @_;
    (defined $variable && $variable =~ /^[\$\@\%]/)
        || confess "variable name does not have a sigil";
    my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    no strict 'refs';
    defined ${$self->name . '::'}{$name} ? 1 : 0;
}

sub get_package_variable {
    my ($self, $variable) = @_;
    (defined $variable && $variable =~ /^[\$\@\%]/)
        || confess "variable name does not have a sigil";
    my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    no strict 'refs';
    # try to fetch it first,.. see what happens
    eval '\\' . $sigil . $self->name . '::' . $name;
    confess "Could not get the package variable ($variable) because : $@" if $@;    
    # if we didn't die, then we can return it
    # NOTE:
    # this is not ideal, better suggestions are welcome
    eval '\\' . $sigil . $self->name . '::' . $name;   
}

sub remove_package_variable {
    my ($self, $variable) = @_;
    (defined $variable && $variable =~ /^[\$\@\%]/)
        || confess "variable name does not have a sigil";
    my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    no strict 'refs';
    delete ${$self->name . '::'}{$name};
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Class - Class Meta Object

=head1 SYNOPSIS

  # use this for introspection ...
  
  package Foo;
  sub meta { Class::MOP::Class->initialize(__PACKAGE__) }
  
  # elsewhere in the code ...
  
  # add a method to Foo ...
  Foo->meta->add_method('bar' => sub { ... })
  
  # get a list of all the classes searched 
  # the method dispatcher in the correct order 
  Foo->meta->class_precedence_list()
  
  # remove a method from Foo
  Foo->meta->remove_method('bar');
  
  # or use this to actually create classes ...
  
  Class::MOP::Class->create('Bar' => '0.01' => (
      superclasses => [ 'Foo' ],
      attributes => [
          Class::MOP:::Attribute->new('$bar'),
          Class::MOP:::Attribute->new('$baz'),          
      ],
      methods => {
          calculate_bar => sub { ... },
          construct_baz => sub { ... }          
      }
  ));

=head1 DESCRIPTION

This is the largest and currently most complex part of the Perl 5 
meta-object protocol. It controls the introspection and 
manipulation of Perl 5 classes (and it can create them too). The 
best way to understand what this module can do, is to read the 
documentation for each of it's methods.

=head1 METHODS

=head2 Self Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class. Thereby allowing B<Class::MOP::Class> to actually 
introspect itself.

As with B<Class::MOP::Attribute>, B<Class::MOP> will actually 
bootstrap this module by installing a number of attribute meta-objects 
into it's metaclass. This will allow this class to reap all the benifits 
of the MOP when subclassing it. 

=back

=head2 Class construction

These methods will handle creating B<Class::MOP::Class> objects, 
which can be used to both create new classes, and analyze 
pre-existing classes. 

This module will internally store references to all the instances 
you create with these methods, so that they do not need to be 
created any more than nessecary. Basically, they are singletons.

=over 4

=item B<create ($package_name, ?$package_version,
                superclasses =E<gt> ?@superclasses, 
                methods      =E<gt> ?%methods, 
                attributes   =E<gt> ?%attributes)>

This returns a B<Class::MOP::Class> object, bringing the specified 
C<$package_name> into existence and adding any of the 
C<$package_version>, C<@superclasses>, C<%methods> and C<%attributes> 
to it.

=item B<initialize ($package_name)>

This initializes and returns returns a B<Class::MOP::Class> object 
for a given a C<$package_name>.

=item B<construct_class_instance ($package_name)>

This will construct an instance of B<Class::MOP::Class>, it is 
here so that we can actually "tie the knot" for B<Class::MOP::Class> 
to use C<construct_instance> once all the bootstrapping is done. This 
method is used internally by C<initialize> and should never be called
from outside of that method really.

=back

=head2 Object instance construction

This method is used to construct an instace structure suitable for 
C<bless>-ing into your package of choice. It works in conjunction 
with the Attribute protocol to collect all applicable attributes. 

This method is B<entirely optional>, it is up to you whether you want 
to use it or not.

=over 4

=item B<construct_instance (%params)>

This will construct and instance using a HASH ref as storage 
(currently only HASH references are supported). This will collect all 
the applicable attributes and layout out the fields in the HASH ref, 
it will then initialize them using either use the corresponding key 
in C<%params> or any default value or initializer found in the 
attribute meta-object.

=back

=head2 Informational 

=over 4

=item B<name>

This is a read-only attribute which returns the package name for the 
given B<Class::MOP::Class> instance.

=item B<version>

This is a read-only attribute which returns the C<$VERSION> of the 
package for the given B<Class::MOP::Class> instance.

=back

=head2 Inheritance Relationships

=over 4

=item B<superclasses (?@superclasses)>

This is a read-write attribute which represents the superclass 
relationships of the class the B<Class::MOP::Class> instance is
associated with. Basically, it can get and set the C<@ISA> for you.

B<NOTE:>
Perl will occasionally perform some C<@ISA> and method caching, if 
you decide to change your superclass relationship at runtime (which 
is quite insane and very much not recommened), then you should be 
aware of this and the fact that this module does not make any 
attempt to address this issue.

=item B<class_precedence_list>

This computes the a list of all the class's ancestors in the same order 
in which method dispatch will be done. This is similair to 
what B<Class::ISA::super_path> does, but we don't remove duplicate names.

=back

=head2 Methods

=over 4

=item B<method_metaclass>

=item B<add_method ($method_name, $method)>

This will take a C<$method_name> and CODE reference to that 
C<$method> and install it into the class's package. 

B<NOTE>: 
This does absolutely nothing special to C<$method> 
other than use B<Sub::Name> to make sure it is tagged with the 
correct name, and therefore show up correctly in stack traces and 
such.

=item B<has_method ($method_name)>

This just provides a simple way to check if the class implements 
a specific C<$method_name>. It will I<not> however, attempt to check 
if the class inherits the method (use C<UNIVERSAL::can> for that).

This will correctly handle functions defined outside of the package 
that use a fully qualified name (C<sub Package::name { ... }>).

This will correctly handle functions renamed with B<Sub::Name> and 
installed using the symbol tables. However, if you are naming the 
subroutine outside of the package scope, you must use the fully 
qualified name, including the package name, for C<has_method> to 
correctly identify it. 

This will attempt to correctly ignore functions imported from other 
packages using B<Exporter>. It breaks down if the function imported 
is an C<__ANON__> sub (such as with C<use constant>), which very well 
may be a valid method being applied to the class. 

In short, this method cannot always be trusted to determine if the 
C<$method_name> is actually a method. However, it will DWIM about 
90% of the time, so it's a small trade off I think.

=item B<get_method ($method_name)>

This will return a CODE reference of the specified C<$method_name>, 
or return undef if that method does not exist.

=item B<remove_method ($method_name)>

This will attempt to remove a given C<$method_name> from the class. 
It will return the CODE reference that it has removed, and will 
attempt to use B<Sub::Name> to clear the methods associated name.

=item B<get_method_list>

This will return a list of method names for all I<locally> defined 
methods. It does B<not> provide a list of all applicable methods, 
including any inherited ones. If you want a list of all applicable 
methods, use the C<compute_all_applicable_methods> method.

=item B<compute_all_applicable_methods>

This will return a list of all the methods names this class will 
respond to, taking into account inheritance. The list will be a list of 
HASH references, each one containing the following information; method 
name, the name of the class in which the method lives and a CODE 
reference for the actual method.

=item B<find_all_methods_by_name ($method_name)>

This will traverse the inheritence hierarchy and locate all methods 
with a given C<$method_name>. Similar to 
C<compute_all_applicable_methods> it returns a list of HASH references 
with the following information; method name (which will always be the 
same as C<$method_name>), the name of the class in which the method 
lives and a CODE reference for the actual method.

The list of methods produced is a distinct list, meaning there are no 
duplicates in it. This is especially useful for things like object 
initialization and destruction where you only want the method called 
once, and in the correct order.

=back

=head2 Attributes

It should be noted that since there is no one consistent way to define 
the attributes of a class in Perl 5. These methods can only work with 
the information given, and can not easily discover information on 
their own. See L<Class::MOP::Attribute> for more details.

=over 4

=item B<attribute_metaclass>

=item B<add_attribute ($attribute_name, $attribute_meta_object)>

This stores a C<$attribute_meta_object> in the B<Class::MOP::Class> 
instance associated with the given class, and associates it with 
the C<$attribute_name>. Unlike methods, attributes within the MOP 
are stored as meta-information only. They will be used later to 
construct instances from (see C<construct_instance> above).
More details about the attribute meta-objects can be found in the 
L<Class::MOP::Attribute> or the L<Class::MOP/The Attribute protocol>
section.

It should be noted that any accessor, reader/writer or predicate 
methods which the C<$attribute_meta_object> has will be installed 
into the class at this time.

=item B<has_attribute ($attribute_name)>

Checks to see if this class has an attribute by the name of 
C<$attribute_name> and returns a boolean.

=item B<get_attribute ($attribute_name)>

Returns the attribute meta-object associated with C<$attribute_name>, 
if none is found, it will return undef. 

=item B<remove_attribute ($attribute_name)>

This will remove the attribute meta-object stored at 
C<$attribute_name>, then return the removed attribute meta-object. 

B<NOTE:> 
Removing an attribute will only affect future instances of 
the class, it will not make any attempt to remove the attribute from 
any existing instances of the class.

It should be noted that any accessor, reader/writer or predicate 
methods which the attribute meta-object stored at C<$attribute_name> 
has will be removed from the class at this time. This B<will> make 
these attributes somewhat inaccessable in previously created 
instances. But if you are crazy enough to do this at runtime, then 
you are crazy enough to deal with something like this :).

=item B<get_attribute_list>

This returns a list of attribute names which are defined in the local 
class. If you want a list of all applicable attributes for a class, 
use the C<compute_all_applicable_attributes> method.

=item B<compute_all_applicable_attributes>

This will traverse the inheritance heirachy and return a list of HASH 
references for all the applicable attributes for this class. The HASH 
references will contain the following information; the attribute name, 
the class which the attribute is associated with and the actual 
attribute meta-object.

=back

=head2 Package Variables

Since Perl's classes are built atop the Perl package system, it is 
fairly common to use package scoped variables for things like static 
class variables. The following methods are convience methods for 
the creation and inspection of package scoped variables.

=over 4

=item B<add_package_variable ($variable_name, ?$initial_value)>

Given a C<$variable_name>, which must contain a leading sigil, this 
method will create that variable within the package which houses the 
class. It also takes an optional C<$initial_value>, which must be a 
reference of the same type as the sigil of the C<$variable_name> 
implies.

=item B<get_package_variable ($variable_name)>

This will return a reference to the package variable in 
C<$variable_name>. 

=item B<has_package_variable ($variable_name)>

Returns true (C<1>) if there is a package variable defined for 
C<$variable_name>, and false (C<0>) otherwise.

=item B<remove_package_variable ($variable_name)>

This will attempt to remove the package variable at C<$variable_name>.

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut