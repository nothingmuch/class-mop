
package Class::MOP;

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION = '0.01';

# my %METAS;
# sub UNIVERSAL::meta { 
#     my $class = blessed($_[0]) || $_[0];
#     $METAS{$class} ||= Class::MOP::Class->initialize($class) 
# }

1;

__END__

=pod

=head1 NAME 

Class::MOP - A Meta Object Protocol for Perl 5

=head1 SYNOPSIS

  # ... coming soon

=head1 DESCRIPTON

This module is an attempt to create a meta object protocol for the 
Perl 5 object system. It makes no attempt to change the behavior or 
characteristics of the Perl 5 object system, only to create a 
protocol for its manipulation and introspection.

That said, it does attempt to create the tools for building a rich 
set of extensions to the Perl 5 object system. Every attempt has been 
made for these tools to keep to the spirit of the Perl 5 object 
system that we all know and love.

=head2 What is a Meta Object Protocol?

A meta object protocol is an API to an object system. 

To be more specific, it is a set of abstractions of the components of 
an object system (typically things like; classes, object, methods, 
object attributes, etc.). These abstractions can then be used to both 
inspect and manipulate the object system which they describe.

It can be said that there are two MOPs for any object system; the 
implicit MOP, and the explicit MOP. The implicit MOP handles things 
like method dispatch or inheritance, which happen automatically as 
part of how the object system works. The explicit MOP typically 
handles the introspection/reflection features of the object system. 
All object systems have implicit MOPs, without one, they would not 
work. Explict MOPs however as less common, and depending on the 
language can vary from restrictive (Reflection in Java or C#) to 
wide open (CLOS is a perfect example). 

=head2 Who is this module for?

This module is specifically for anyone who has ever created or 
wanted to create a module for the Class:: namespace. The tools which 
this module will provide will hopefully make it easier to do more 
complex things with Perl 5 classes by removing such barriers as 
the need to hack the symbol tables, or understand the fine details 
of method dispatch. 

=head2 What changes do I have to make to use this module?

This module was designed to be as unintrusive as possible. So many of 
it's features are accessible without B<any> change to your existsing 
code at all. It is meant to be a compliment to your existing code and 
not an intrusion on your code base.

The only feature which requires additions to your code are the 
attribute handling and instance construction features. The only reason 
for this is because Perl 5's object system does not actually have 
these features built in. More information about this feature can be 
found below.

=head2 A Note about Performance?

It is a common misconception that explict MOPs are performance drains. 
But this is not a universal truth at all, it is an side-effect of 
specific implementations. For instance, using Java reflection is much 
slower because the JVM cannot take advantage of any compiler 
optimizations, and the JVM has to deal with much more runtime type 
information as well. Reflection in C# is marginally better as it was 
designed into the language and runtime (the CLR). In contrast, CLOS 
(the Common Lisp Object System) was built to support an explicit MOP, 
and so performance is tuned for it. 

This library in particular does it's absolute best to avoid putting 
B<any> drain at all upon your code's performance, while still trying 
to make sure it is fast as well (although only as a secondary 
concern).

=head1 PROTOCOLS

The protocol is divided into 3 main sub-protocols:

=over 4

=item The Class protocol

This provides a means of manipulating and introspecting a Perl 5 
class. It handles all of symbol table hacking for you, and provides 
a rich set of methods that go beyond simple package introspection.

=item The Attribute protocol

This provides a consistent represenation for an attribute of a 
Perl 5 class. Since there are so many ways to create and handle 
atttributes in Perl 5 OO, this attempts to provide as much of a 
unified approach as possible, while giving the freedom and 
flexibility to subclass for specialization.

=item The Method protocol

This provides a means of manipulating and introspecting methods in 
the Perl 5 object system. As with attributes, there are many ways to 
approach this topic, so we try to keep it pretty basic, while still 
making it possible to extend the system in many ways.

=back

What follows is a more detailed documentation on each specific sub 
protocol.

=head2 The Class protocol

=head3 Class construction

These methods handle creating Class objects, which can be used to 
both create new classes, and analyze pre-existing ones. 

Class::MOP will internally store weakened references to all the 
instances you create with these methods, so that they do not need 
to be created any more than nessecary. 

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

=head3 Instance construction

=over 4

=item B<construct_instance ($canidate, %params)>

This will construct and instance using the C<$canidate> as storage 
(currently only HASH references are supported). This will collect all 
the applicable attribute meta-objects and layout out the fields in the 
C<$canidate>, it will then initialize them using either use the 
corresponding key in C<%params> or any default value or initializer 
found in the attribute meta-object.

=back

=head3 Informational 

=over 4

=item B<name>

This is a read-only attribute which returns the package name that 
the Class is stored in.

=item B<version>

This is a read-only attribute which returns the C<$VERSION> of the 
package the Class is stored in.

=back

=head3 Inheritance Relationships

=over 4

=item B<superclasses (?@superclasses)>

This is a read-write attribute which represents the superclass 
relationships of this Class. Basically, it can get and set the 
C<@ISA> for you.

=item B<class_precedence_list>

This computes the a list of the Class's ancestors in the same order 
in which method dispatch will be done. 

=back

=head3 Methods

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

=back

=head3 Attributes

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

=head2 The Attribute Protocol

This protocol is almost entirely an invention of this module. This is
because Perl 5 does not have consistent notion of what is an attribute 
of a class. There are so many ways in which this is done, and very few 
(if any) are discoverable by this module.

So, all that said, this module attempts to inject some order into this 
chaos, by introducing a more consistent approach.

=head3 Creation

=over 4

=item B<new ($name, %accessor_description, $class_initialization_arg, $default_value)>

  Class::MOP::Attribute->new('$foo' => (
      accessor => 'foo',        # dual purpose get/set accessor
      init_arg => '-foo',       # class->new will look for a -foo key
      default  => 'BAR IS BAZ!' # if no -foo key is provided, use this
  ));
  
  Class::MOP::Attribute->new('$.bar' => (
      reader   => 'bar',        # getter
      writer   => 'set_bar',    # setter      
      init_arg => '-bar',       # class->new will look for a -bar key
      # no default value means it is undef
  ));  

=back 

=head3 Informational

=over 4

=item B<name>

=item B<accessor>

=item B<reader>

=item B<writer>

=item B<init_arg>

=item B<default>

=back

=head3 Informational predicates

=over 4

=item B<has_accessor>

Returns true if this attribute uses a get/set accessor, and false 
otherwise

=item B<has_reader>

Returns true if this attribute has a reader, and false otherwise

=item B<has_writer>

Returns true if this attribute has a writer, and false otherwise

=item B<has_init_arg>

Returns true if this attribute has a class intialization argument, and 
false otherwise

=item B<has_default>

Returns true if this attribute has a default value, and false 
otherwise.

=back

=head3 Attribute Accessor generation

=over 4

=item B<generate_accessors>

This allows the attribute to generate code for it's own accessor 
methods. This is mostly part of an internal protocol between the class 
and it's own attributes, see the C<create_all_accessors> method above.

=back

=head2 The Method Protocol

This protocol is very small, since methods in Perl 5 are just 
subroutines within the particular package. Basically all we do is to 
bless the subroutine and provide some very simple introspection 
methods for it.

=head1 SEE ALSO

=over 4

=item "The Art of the Meta Object Protocol"

=item "Advances in Object-Oriented Metalevel Architecture and Reflection"

=back

=head1 AUTHOR

Stevan Little E<gt>stevan@iinteractive.comE<lt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
