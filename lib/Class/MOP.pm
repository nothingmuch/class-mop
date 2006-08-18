
package Class::MOP;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'weaken';

use Class::MOP::Class;
use Class::MOP::Attribute;
use Class::MOP::Method;

use Class::MOP::Class::Immutable;

our $VERSION   = '0.33';
our $AUTHORITY = 'cpan:STEVAN';

{
    # Metaclasses are singletons, so we cache them here.
    # there is no need to worry about destruction though
    # because they should die only when the program dies.
    # After all, do package definitions even get reaped?
    my %METAS;  
    
    # means of accessing all the metaclasses that have 
    # been initialized thus far (for mugwumps obj browser)
    sub get_all_metaclasses         {        %METAS         }            
    sub get_all_metaclass_instances { values %METAS         } 
    sub get_all_metaclass_names     { keys   %METAS         }     
    sub get_metaclass_by_name       { $METAS{$_[0]}         }
    sub store_metaclass_by_name     { $METAS{$_[0]} = $_[1] }  
    sub weaken_metaclass            { weaken($METAS{$_[0]}) }            
    sub does_metaclass_exist        { exists $METAS{$_[0]} && defined $METAS{$_[0]} }
    sub remove_metaclass_by_name    { $METAS{$_[0]} = undef }     
    
    # NOTE:
    # We only cache metaclasses, meaning instances of 
    # Class::MOP::Class. We do not cache instance of 
    # Class::MOP::Package or Class::MOP::Module. Mostly
    # because I don't yet see a good reason to do so.        
}

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

## --------------------------------------------------------
## Class::MOP::Package

Class::MOP::Package->meta->add_attribute(
    Class::MOP::Attribute->new('$:package' => (
        reader   => {
            # NOTE: we need to do this in order 
            # for the instance meta-object to 
            # not fall into meta-circular death
            'name' => sub { (shift)->{'$:package'} }
        },
        init_arg => ':package',
    ))
);

Class::MOP::Package->meta->add_attribute(
    Class::MOP::Attribute->new('%:namespace' => (
        reader => {
            # NOTE:
            # because of issues with the Perl API 
            # to the typeglob in some versions, we 
            # need to just always grab a new 
            # reference to the hash here. Ideally 
            # we could just store a ref and it would
            # Just Work, but oh well :\
            'namespace' => sub { 
                no strict 'refs';
                \%{$_[0]->name . '::'} 
            }
        },
        # NOTE:
        # protect this from silliness 
        init_arg => '!............( DO NOT DO THIS )............!',
    ))
);

# NOTE:
# use the metaclass to construct the meta-package
# which is a superclass of the metaclass itself :P
Class::MOP::Package->meta->add_method('initialize' => sub {
    my $class        = shift;
    my $package_name = shift;
    $class->meta->new_object(':package' => $package_name, @_);  
});

## --------------------------------------------------------
## Class::MOP::Module

# NOTE:
# yeah this is kind of stretching things a bit, 
# but truthfully the version should be an attribute
# of the Module, the weirdness comes from having to 
# stick to Perl 5 convention and store it in the 
# $VERSION package variable. Basically if you just 
# squint at it, it will look how you want it to look. 
# Either as a package variable, or as a attribute of
# the metaclass, isn't abstraction great :)

Class::MOP::Module->meta->add_attribute(
    Class::MOP::Attribute->new('$:version' => (
        reader => {
            'version' => sub {  
                my $self = shift;
                ${$self->get_package_symbol('$VERSION')};
            }
        },
        # NOTE:
        # protect this from silliness 
        init_arg => '!............( DO NOT DO THIS )............!',
    ))
);

# NOTE:
# By following the same conventions as version here, 
# we are opening up the possibility that people can 
# use the $AUTHORITY in non-Class::MOP modules as 
# well.  

Class::MOP::Module->meta->add_attribute(
    Class::MOP::Attribute->new('$:authority' => (
        reader => {
            'authority' => sub {  
                my $self = shift;
                ${$self->get_package_symbol('$AUTHORITY')};
            }
        },       
        # NOTE:
        # protect this from silliness 
        init_arg => '!............( DO NOT DO THIS )............!',
    ))
);

## --------------------------------------------------------
## Class::MOP::Class

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('%:attributes' => (
        reader   => {
            # NOTE: we need to do this in order 
            # for the instance meta-object to 
            # not fall into meta-circular death            
            'get_attribute_map' => sub { (shift)->{'%:attributes'} }
        },
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

Class::MOP::Class->meta->add_attribute(
    Class::MOP::Attribute->new('$:instance_metaclass' => (
        reader   => {
            # NOTE: we need to do this in order 
            # for the instance meta-object to 
            # not fall into meta-circular death            
            'instance_metaclass' => sub { (shift)->{'$:instance_metaclass'} }
        },
        init_arg => ':instance_metaclass',
        default  => 'Class::MOP::Instance',        
    ))
);

# NOTE:
# we don't actually need to tie the knot with 
# Class::MOP::Class here, it is actually handled 
# within Class::MOP::Class itself in the 
# construct_class_instance method. 

## --------------------------------------------------------
## Class::MOP::Attribute

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('name' => (
        reader => {
            # NOTE: we need to do this in order 
            # for the instance meta-object to 
            # not fall into meta-circular death            
            'name' => sub { (shift)->{name} }
        }
    ))
);

Class::MOP::Attribute->meta->add_attribute(
    Class::MOP::Attribute->new('associated_class' => (
        reader => {
            # NOTE: we need to do this in order 
            # for the instance meta-object to 
            # not fall into meta-circular death            
            'associated_class' => sub { (shift)->{associated_class} }
        }
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
    Class::MOP::Attribute->new('clearer' => (
        reader    => 'clearer',
        predicate => 'has_clearer',
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
        
    (Class::MOP::Attribute::is_default_a_coderef(\%options))
        || confess("References are not allowed as default values, you must ". 
                   "wrap then in a CODE reference (ex: sub { [] } and not [])")
            if exists $options{default} && ref $options{default};        

    # return the new object
    $class->meta->new_object(name => $name, %options);
});

Class::MOP::Attribute->meta->add_method('clone' => sub {
    my $self  = shift;
    $self->meta->clone_object($self, @_);  
});

## --------------------------------------------------------
## Now close all the Class::MOP::* classes

Class::MOP::Package  ->meta->make_immutable(inline_constructor => 0);
Class::MOP::Module   ->meta->make_immutable(inline_constructor => 0);
Class::MOP::Class    ->meta->make_immutable(inline_constructor => 0);
Class::MOP::Attribute->meta->make_immutable(inline_constructor => 0);
Class::MOP::Method   ->meta->make_immutable(inline_constructor => 0);
Class::MOP::Instance ->meta->make_immutable(inline_constructor => 0);
Class::MOP::Object   ->meta->make_immutable(inline_constructor => 0);

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

This documentation is admittedly sparse on details, as time permits 
I will try to improve them. For now, I suggest looking at the items 
listed in the L<SEE ALSO> section for more information. In particular 
the book "The Art of the Meta Object Protocol" was very influential 
in the development of this system.

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

=head1 FUNCTIONS

Class::MOP holds a cache of metaclasses, the following are functions 
(B<not methods>) which can be used to access that cache. It is not 
recommended that you mess with this, bad things could happen. But if 
you are brave and willing to risk it, go for it.

=over 4

=item B<get_all_metaclasses>

This will return an hash of all the metaclass instances that have 
been cached by B<Class::MOP::Class> keyed by the package name. 

=item B<get_all_metaclass_instances>

This will return an array of all the metaclass instances that have 
been cached by B<Class::MOP::Class>.

=item B<get_all_metaclass_names>

This will return an array of all the metaclass names that have 
been cached by B<Class::MOP::Class>.

=item B<get_metaclass_by_name ($name)>

=item B<store_metaclass_by_name ($name, $meta)>

=item B<weaken_metaclass ($name)>

=item B<does_metaclass_exist ($name)>

=item B<remove_metaclass_by_name ($name)>

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
 Class/MOP.pm                   78.0   87.5   55.6   71.4  100.0   12.4   76.8
 Class/MOP/Attribute.pm         83.4   75.6   86.7   94.4  100.0    8.9   85.2
 Class/MOP/Class.pm             96.9   75.8   43.2   98.0  100.0   55.3   83.6
 Class/MOP/Class/Immutable.pm   88.5   53.8    n/a   95.8  100.0    1.1   84.7
 Class/MOP/Instance.pm          87.9   75.0   33.3   89.7  100.0   10.1   89.1
 Class/MOP/Method.pm            97.6   60.0   57.9   76.9  100.0    1.5   82.8
 Class/MOP/Module.pm            87.5    n/a   11.1   83.3  100.0    0.3   66.7
 Class/MOP/Object.pm           100.0    n/a   33.3  100.0  100.0    0.1   89.5
 Class/MOP/Package.pm           95.1   69.0   33.3  100.0  100.0    9.9   85.5
 metaclass.pm                  100.0  100.0   83.3  100.0    n/a    0.5   97.7
 ---------------------------- ------ ------ ------ ------ ------ ------ ------
 Total                          91.5   72.1   48.8   90.7  100.0  100.0   84.2
 ---------------------------- ------ ------ ------ ------ ------ ------ ------

=head1 ACKNOWLEDGEMENTS

=over 4

=item Rob Kinyon

Thanks to Rob for actually getting the development of this module kick-started. 

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
