
package Class::MOP::Class;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype';
use Sub::Name    'subname';
use B            'svref_2object';

our $VERSION = '0.01';

# Creation

{
    # Metaclasses are singletons, so we cache them here.
    # there is no need to worry about destruction though
    # because they should die only when the program dies.
    # After all, do package definitions even get reaped?
    my %METAS;
    sub initialize {
        my ($class, $package_name) = @_;
        (defined $package_name && $package_name)
            || confess "You must pass a package name";
        $METAS{$package_name} ||= bless [ $package_name, {} ] => blessed($class) || $class;
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
    if (exists $options{methods}) {
        foreach my $method_name (keys %{$options{methods}}) {
            $meta->add_method($method_name, $options{methods}->{$method_name});
        }
    }
    return $meta;
}

# Informational 

sub name { ${$_[0]}[0] }

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
    my $_find_subroutine_package_name = sub { eval { svref_2object($_[0])->GV->STASH->NAME } };
    my $_find_subroutine_name         = sub { eval { svref_2object($_[0])->GV->NAME        } };

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

## Recursive Version of compute_all_applicable_methods
# sub compute_all_applicable_methods {
#     my ($self, $seen) = @_;
#     $seen ||= {};
#     (
#         (map { 
#             if (exists $seen->{$_}) { 
#                 ();
#             }
#             else {
#                 $seen->{$_}++;
#                 {
#                     name  => $_, 
#                     class => $self->name,
#                     code  => $self->get_method($_)
#                 };
#             }
#         } $self->get_method_list()),
#         map { 
#             $self->initialize($_)->compute_all_applicable_methods($seen)
#         } $self->superclasses()
#     );
# }

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

sub has_attribute {} 
sub get_attribute {} 
sub add_attribute {} 
sub remove_attribute {} 
sub get_attribute_list {} 
sub compute_all_applicable_attributes {} 
sub create_all_accessors {}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Class - Class Meta Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 Class construction

These methods handle creating Class objects, which can be used to 
both create new classes, and analyze pre-existing ones. 

This module will internally store references to all the instances 
you create with these methods, so that they do not need to be 
created any more than nessecary. Basically, they are singletons.

=over 4

=item B<create ($package_name, ?$package_version,
                superclasses => ?@superclasses, 
                methods      => ?%methods, 
                attributes   => ?%attributes)>

This returns the basic Class object, bringing the specified 
C<$package_name> into existence and adding any of the 
C<$package_version>, C<@superclasses>, C<%methods> and C<%attributes> 
to it.

=item B<initialize ($package_name)>

This initializes a Class object for a given a C<$package_name>.

=back

=head2 Instance construction

=over 4

=item B<construct_instance ($canidate, %params)>

This will construct and instance using the C<$canidate> as storage 
(currently only HASH references are supported). This will collect all 
the applicable attribute meta-objects and layout out the fields in the 
C<$canidate>, it will then initialize them using either use the 
corresponding key in C<%params> or any default value or initializer 
found in the attribute meta-object.

=back

=head2 Informational 

=over 4

=item B<name>

This is a read-only attribute which returns the package name that 
the Class is stored in.

=item B<version>

This is a read-only attribute which returns the C<$VERSION> of the 
package the Class is stored in.

=back

=head2 Inheritance Relationships

=over 4

=item B<superclasses (?@superclasses)>

This is a read-write attribute which represents the superclass 
relationships of this Class. Basically, it can get and set the 
C<@ISA> for you.

=item B<class_precedence_list>

This computes the a list of the Class's ancestors in the same order 
in which method dispatch will be done. 

=back

=head2 Methods

=over 4

=item B<add_method ($method_name, $method)>

This will take a C<$method_name> and CODE reference to that 
C<$method> and install it into the Class. 

B<NOTE> : This does absolutely nothing special to C<$method> 
other than use B<Sub::Name> to make sure it is tagged with the 
correct name, and therefore show up correctly in stack traces and 
such.

=item B<has_method ($method_name)>

This just provides a simple way to check if the Class implements 
a specific C<$method_name>. It will I<not> however, attempt to check 
if the class inherits the method.

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
90% of the time, so it's a small trade off IMO.

=item B<get_method ($method_name)>

This will return a CODE reference of the specified C<$method_name>, 
or return undef if that method does not exist.

=item B<remove_method ($method_name)>

This will attempt to remove a given C<$method_name> from the Class. 
It will return the CODE reference that it has removed, and will 
attempt to use B<Sub::Name> to clear the methods associated name.

=item B<get_method_list>

This will return a list of method names for all I<locally> defined 
methods. It does B<not> provide a list of all applicable methods, 
including any inherited ones. If you want a list of all applicable 
methods, use the C<compute_all_applicable_methods> method.

=item B<compute_all_applicable_methods>

This will return a list of all the methods names this Class will 
support, taking into account inheritance. The list will be a list of 
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
their own.

=over 4

=item B<add_attribute ($attribute_name, $attribute_meta_object)>

This stores a C<$attribute_meta_object> in the Class object and 
associates it with the C<$attribute_name>. Unlike methods, attributes 
within the MOP are stored as meta-information only. They will be used 
later to construct instances from (see C<construct_instance> above).
More details about the attribute meta-objects can be found in the 
L<The Attribute protocol> section of this document.

=item B<has_attribute ($attribute_name)>

Checks to see if this Class has an attribute by the name of 
C<$attribute_name> and returns a boolean.

=item B<get_attribute ($attribute_name)>

Returns the attribute meta-object associated with C<$attribute_name>, 
if none is found, it will return undef. 

=item B<remove_attribute ($attribute_name)>

This will remove the attribute meta-object stored at 
C<$attribute_name>, then return the removed attribute meta-object. 

B<NOTE:> Removing an attribute will only affect future instances of 
the class, it will not make any attempt to remove the attribute from 
any existing instances of the class.

=item B<get_attribute_list>

This returns a list of attribute names which are defined in the local 
class. If you want a list of all applicable attributes for a class, 
use the C<compute_all_applicable_attributes> method.

=item B<compute_all_applicable_attributes>

This will traverse the inheritance heirachy and return a list of HASH 
references for all the applicable attributes for this class. The HASH 
references will contain the following information; the attribute name, 
the class which the attribute is associated with and the actual 
attribute meta-object

=item B<create_all_accessors>

This will communicate with all of the classes attributes to create
and install the appropriate accessors. (see L<The Attribute Protocol> 
below for more details).

=back

=head1 AUTHOR

Stevan Little E<gt>stevan@iinteractive.comE<lt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut