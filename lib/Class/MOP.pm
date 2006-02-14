
package Class::MOP;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util ();

use Class::MOP::Class;
use Class::MOP::Attribute;
use Class::MOP::Method;

our $VERSION = '0.10';

## ----------------------------------------------------------------------------
## Setting up our environment ...
## ----------------------------------------------------------------------------
## Class::MOP needs to have a few things in the global perl environment so 
## that it can operate effectively. Those things are done here.
## ----------------------------------------------------------------------------

# ... nothing yet actually ;)

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
    Class::MOP::Attribute->new('$:package' => (
        reader   => 'name',
        init_arg => ':package',
    ))
);

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('%:attributes' => (
        reader   => 'get_attribute_map',
        init_arg => ':attributes',
        default  => sub { {} }
    ))
);

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('$:attribute_metaclass' => (
        reader   => 'attribute_metaclass',
        init_arg => ':attribute_metaclass',
        default  => 'Class::MOP::Attribute',
    ))
);

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('$:method_metaclass' => (
        reader   => 'method_metaclass',
        init_arg => ':method_metaclass',
        default  => 'Class::MOP::Method',        
    ))
);

## Class::MOP::Attribute

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('name' => (
        reader => 'name'
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('associated_class' => (
        reader => 'associated_class'
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('accessor' => (
        reader    => 'accessor',
        predicate => 'has_accessor',
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('reader' => (
        reader    => 'reader',
        predicate => 'has_reader',
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('writer' => (
        reader    => 'writer',
        predicate => 'has_writer',
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('predicate' => (
        reader    => 'predicate',
        predicate => 'has_predicate',
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('init_arg' => (
        reader    => 'init_arg',
        predicate => 'has_init_arg',
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('default' => (
        # default has a custom 'reader' method ...
        predicate => 'has_default',
    ))
);


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
    $options{init_arg} = $name 
        if not exists $options{init_arg};

    # return the new object
    $class->meta->new_object(name => $name, %options);
});

Class::MOP::Attribute->meta->add_method('clone' => sub {
    my $self  = shift;
    my $class = $self->associated_class;
    $self->detach_from_class() if defined $class;
    my $clone = $self->meta->clone_object($self, @_);  
    if (defined $class) {
        $self->attach_to_class($class);
        $clone->attach_to_class($class);
    }
    return $clone;  
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
its features are accessible without B<any> change to your existsing 
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

=head2 About Metaclass compatibility

This module makes sure that all metaclasses created are both upwards 
and downwards compatible. The topic of metaclass compatibility is 
highly esoteric and is something only encountered when doing deep and 
involved metaclass hacking. There are two basic kinds of metaclass 
incompatibility; upwards and downwards. 

Upwards metaclass compatibility means that the metaclass of a 
given class is either the same as (or a subclass of) all of the 
class's ancestors.

Downward metaclass compatibility means that the metaclasses of a 
given class's anscestors are all either the same as (or a subclass 
of) that metaclass.

Here is a diagram showing a set of two classes (C<A> and C<B>) and 
two metaclasses (C<Meta::A> and C<Meta::B>) which have correct  
metaclass compatibility both upwards and downwards.

    +---------+     +---------+
    | Meta::A |<----| Meta::B |      <....... (instance of  )
    +---------+     +---------+      <------- (inherits from)  
         ^               ^
         :               :
    +---------+     +---------+
    |    A    |<----|    B    |
    +---------+     +---------+

As I said this is a highly esoteric topic and one you will only run 
into if you do a lot of subclassing of B<Class::MOP::Class>. If you 
are interested in why this is an issue see the paper 
I<Uniform and safe metaclass composition> linked to in the 
L<SEE ALSO> section of this document.

=head2 Using custom metaclasses

Always use the metaclass pragma when using a custom metaclass, this 
will ensure the proper initialization order and not accidentely 
create an incorrect type of metaclass for you. This is a very rare 
problem, and one which can only occur if you are doing deep metaclass 
programming. So in other words, don't worry about it.

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

=head2 Papers

=over 4

=item Uniform and safe metaclass composition

An excellent paper by the people who brought us the original Traits paper. 
This paper is on how Traits can be used to do safe metaclass composition, 
and offers an excellent introduction section which delves into the topic of 
metaclass compatibility.

L<http://www.iam.unibe.ch/~scg/Archive/Papers/Duca05ySafeMetaclassTrait.pdf>

=item Safe Metaclass Programming

This paper seems to precede the above paper, and propose a mix-in based 
approach as opposed to the Traits based approach. Both papers have similar 
information on the metaclass compatibility problem space. 

L<http://citeseer.ist.psu.edu/37617.html>

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
like this module is L<Class::Meta>, although it's philosophy and the MOP it 
creates are very different from this modules. 

=head1 BUGS

All complex software has bugs lurking in it, and this module is no 
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 CODE COVERAGE

I use L<Devel::Cover> to test the code coverage of my tests, below is the 
L<Devel::Cover> report on this module's test suite.

 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 File                           stmt   bran   cond    sub    pod   time  total
 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 Class/MOP.pm                  100.0  100.0  100.0  100.0    n/a   21.4  100.0
 Class/MOP/Attribute.pm        100.0  100.0   88.9  100.0  100.0   27.1   99.3
 Class/MOP/Class.pm            100.0  100.0   93.7  100.0  100.0   44.8   99.1
 Class/MOP/Method.pm           100.0  100.0   83.3  100.0  100.0    4.8   97.1
 metaclass.pm                  100.0  100.0   80.0  100.0    n/a    1.9   97.3
 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 Total                         100.0  100.0   92.2  100.0  100.0  100.0   99.0
 ---------------------------- ------ ------ ------ ------ ------ ------ ------

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
