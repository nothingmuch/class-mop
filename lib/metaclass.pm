
package metaclass;

use strict;
use warnings;

use Carp 'confess';

our $VERSION = '0.01';

use Class::MOP;

sub import {
    shift;
    my $metaclass = shift || 'Class::MOP::Class';
    my %options   = @_;
    my $package   = caller();
    
    ($metaclass->isa('Class::MOP::Class'))
        || confess 'The metaclass must be derived from Class::MOP::Class';
    
    # create a meta object so we can install &meta
    my $meta = $metaclass->initialize($package => %options);
    $meta->add_method('meta' => sub {
        # we must re-initialize so that it 
        # works as expected in subclasses, 
        # since metaclass instances are 
        # singletons, this is not really a 
        # big deal anyway.
        $metaclass->initialize($_[0] => %options)
    });
}

=pod

NOTES

Okay, the metaclass constraint issue is a bit of a PITA.

Especially in the context of MI, where we end up with an 
explosion of metaclasses.

SOOOO

Instead of auto-composing metaclasses using inheritance 
(which is problematic at best, and totally wrong at worst, 
especially in the light of methods of Class::MOP::Class 
which are overridden by subclasses (try to figure out how 
LazyClass and InsideOutClass could be composed, it is not
even possible)) we use a trait model.

It will be similar to Class::Trait, except that there is 
no such thing as a trait, a class isa trait and a trait 
isa class, more like Scala really.

This way we get several benefits:

1) Classes can be composed like traits, and it Just Works.

2) Metaclasses can be composed this way too :)

3) When solving the metaclass constraint, we create an 
   anon-metaclass, and compose the parent's metaclasses 
   into it. This allows for conflict checking trait-style 
   which should inform us of any issues right away.
   
Misc. Details:

Class metaclasses must be composed, but so must any 
associated Attribute and Method metaclasses. However, this 
is not always relevant since I should be able to create a 
class which has lazy attributes, and then create a subclass 
of that class whose attributes are not lazy.


=cut

1;

__END__

=pod

=head1 NAME

metaclass - a pragma for installing using Class::MOP metaclasses

=head1 SYNOPSIS

  use metaclass 'MyMetaClass';
  
  use metaclass 'MyMetaClass' => (
      ':attribute_metaclass' => 'MyAttributeMetaClass',
      ':method_metaclass'    => 'MyMethodMetaClass',    
  );

=head1 DESCRIPTION

This is a pragma to make it easier to use a specific metaclass 
and it's 

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut