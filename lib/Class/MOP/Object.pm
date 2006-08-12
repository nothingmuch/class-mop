
package Class::MOP::Object;

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Object - Object Meta Object

=head1 DESCRIPTION

This class is basically a stub, it provides no functionality at all, 
and really just exists to make the Class::MOP metamodel complete.

                         ......
                        :      :                  
                        :      v
                  +-------------------+
            +-----| Class::MOP::Class |
            |     +-------------------+
            |        ^      ^       ^
            v        :      :       :
  +--------------------+    :      +--------------------+
  | Class::MOP::Module |    :      | Class::MOP::Object |
  +--------------------+    :      +--------------------+
            |               :                ^
            |               :                |
            |    +---------------------+     |
            +--->| Class::MOP::Package |-----+
                 +---------------------+
                 
  legend:
    ..(is an instance of)..>
    --(is a subclass of)-->

A deeper discussion of this model is currently beyond the scope of 
this documenation. 
  
=head1 METHODS

=over 4

=item B<meta>

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut