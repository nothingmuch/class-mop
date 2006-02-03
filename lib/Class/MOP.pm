
package Class::MOP;

use strict;
use warnings;

use Scalar::Util 'blessed';
use Carp         'confess';

use Class::MOP::Class;
use Class::MOP::Attribute;
use Class::MOP::Method;

our $VERSION = '0.03';

sub import {
    shift;
    return unless @_;
    if ($_[0] eq ':universal') {
        *UNIVERSAL::meta = sub { 
            Class::MOP::Class->initialize(blessed($_[0]) || $_[0]) 
        };
    }
    else {
        my $pkg = caller();
        no strict 'refs';
        *{$pkg . '::' . $_[0]} = sub { 
            Class::MOP::Class->initialize(blessed($_[0]) || $_[0]) 
        };        
    }
}

## ----------------------------------------------------------------------------
## Bootstrapping 
## ----------------------------------------------------------------------------
## The code below here is to bootstrap our MOP with itself. This is also 
## sometimes called "tying the knot". By doing this, we make it much easier
## to extend the MOP through subclassing and such since now you can use the
## MOP itself to extend itself. 
## 
## Yes, I know, thats weird and insane, but it's a good thing, trust me :)
## ---------------------------------------------------------------------------- 

# We need to add in the meta-attributes here so that 
# any subclass of Class::MOP::* will be able to 
# inherit them using &construct_instance

## Class::MOP::Class

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('$:pkg' => (
        init_arg => ':pkg'
    ))
);

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('%:attrs' => (
        init_arg => ':attrs',
        default  => sub { {} }
    ))
);

## Class::MOP::Attribute

Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('name'));
Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('accessor'));
Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('reader'));
Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('writer'));
Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('predicate'));
Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('init_arg'));
Class::MOP::Attribute->meta->add_attribute(Class::MOP::Attribute->new('default'));

# NOTE: (meta-circularity)
# This should be one of the last things done
# it will "tie the knot" with Class::MOP::Attribute
# so that it uses the attributes meta-objects 
# to construct itself. 
Class::MOP::Attribute->meta->add_method('new' => sub {
    my $class   = shift;
    my $name    = shift;
    my %options = @_;    
        
    (defined $name && $name)
        || confess "You must provide a name for the attribute";
    (!exists $options{reader} && !exists $options{writer})
        || confess "You cannot declare an accessor and reader and/or writer functions"
            if exists $options{accessor};
            
    bless $class->meta->construct_instance(name => $name, %options) => $class;
});

1;

__END__

=pod

=head1 NAME 

Class::MOP - A Meta Object Protocol for Perl 5

=head1 SYNOPSIS

  # ... This will come later, for now see
  # the other SYNOPSIS for more information

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

=head2 Yet Another Class Builder!! Why?

This is B<not> a class builder so much as it is a I<class builder 
B<builder>>. My intent is that an end user does not use this module 
directly, but instead this module is used by module authors to 
build extensions and features onto the Perl 5 object system. 

=head2 Who is this module for?

This module is specifically for anyone who has ever created or 
wanted to create a module for the Class:: namespace. The tools which 
this module will provide will hopefully make it easier to do more 
complex things with Perl 5 classes by removing such barriers as 
the need to hack the symbol tables, or understand the fine details 
of method dispatch. 

=head2 What changes do I have to make to use this module?

This module was designed to be as unintrusive as possible. Many of 
it's features are accessible without B<any> change to your existsing 
code at all. It is meant to be a compliment to your existing code and 
not an intrusion on your code base. Unlike many other B<Class::> 
modules, this module B<does not> require you subclass it, or even that 
you C<use> it in within your module's package. 

The only features which requires additions to your code are the 
attribute handling and instance construction features, and these are
both completely optional features. The only reason for this is because 
Perl 5's object system does not actually have these features built 
in. More information about this feature can be found below.

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
B<any> drain at all upon your code's performance. In fact, by itself 
it does nothing to affect your existing code. So you only pay for 
what you actually use.

=head1 PROTOCOLS

The protocol is divided into 3 main sub-protocols:

=over 4

=item The Class protocol

This provides a means of manipulating and introspecting a Perl 5 
class. It handles all of symbol table hacking for you, and provides 
a rich set of methods that go beyond simple package introspection.

See L<Class::MOP::Class> for more details.

=item The Attribute protocol

This provides a consistent represenation for an attribute of a 
Perl 5 class. Since there are so many ways to create and handle 
atttributes in Perl 5 OO, this attempts to provide as much of a 
unified approach as possible, while giving the freedom and 
flexibility to subclass for specialization.

See L<Class::MOP::Attribute> for more details.

=item The Method protocol

This provides a means of manipulating and introspecting methods in 
the Perl 5 object system. As with attributes, there are many ways to 
approach this topic, so we try to keep it pretty basic, while still 
making it possible to extend the system in many ways.

See L<Class::MOP::Method> for more details.

=back

=head1 SEE ALSO

=head2 Books

There are very few books out on Meta Object Protocols and Metaclasses 
because it is such an esoteric topic. The following books are really 
the only ones I have found. If you know of any more, B<I<please>> 
email me and let me know, I would love to hear about them.

=over 4

=item "The Art of the Meta Object Protocol"

=item "Advances in Object-Oriented Metalevel Architecture and Reflection"

=item "Putting MetaClasses to Work"

=item "Smalltalk: The Language"

=back

=head2 Prior Art

=over 4

=item The Perl 6 MetaModel work in the Pugs project

=over 4

=item L<http://svn.openfoundry.org/pugs/perl5/Perl6-MetaModel>

=item L<http://svn.openfoundry.org/pugs/perl5/Perl6-ObjectSpace>

=back

=back

=head1 SIMILAR MODULES

As I have said above, this module is a class-builder-builder, so it is 
not the same thing as modules like L<Class::Accessor> and 
L<Class::MethodMaker>. That being said there are very few modules on CPAN 
with similar goals to this module. The one I have found which is most 
like this module is L<Class::Meta>, although it's philosophy is very 
different from this module. 

To start with, it provides wrappers around common Perl data types, and even 
extends those types with more specific subtypes. This module does not 
go into that area at all. 

L<Class::Meta> also seems to create it's own custom meta-object protocol, 
which is both more restrictive and more featureful than the vanilla 
Perl 5 one. This module attempts to model the existing Perl 5 MOP as it is.

It's introspection capabilities also seem to be heavily rooted in this 
custom MOP, so that you can only introspect classes which are already 
created with L<Class::Meta>. This module does not make such restictions.

Now, all this said, L<Class::Meta> is much more featureful than B<Class::MOP> 
would ever try to be. But B<Class::MOP> has some features which L<Class::Meta>
could not easily implement. It would be very possible to completely re-implement 
L<Class::Meta> using B<Class::MOP> and bring some of these features to 
L<Class::Meta> though. 

But in the end, this module's admitedly ambitious goals have no direct equal 
on CPAN since surely no one has been crazy enough to try something as silly 
as this ;) until now.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no 
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 ACKNOWLEDGEMENTS

=over 4

=item Rob Kinyon E<lt>rob@iinteractive.comE<gt>

Thanks to Rob for actually getting the development of this module kick-started. 

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
