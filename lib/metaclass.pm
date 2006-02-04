
package metaclass;

use strict;
use warnings;

use Carp 'confess';

our $VERSION = '0.01';

use Class::MOP;

sub import {
    shift;
    my $metaclass = shift;
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

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut