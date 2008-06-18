
package Class::MOP::Object;

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION   = '0.63';
our $AUTHORITY = 'cpan:STEVAN';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

# RANT:
# Cmon, how many times have you written 
# the following code while debugging:
# 
#  use Data::Dumper; 
#  warn Dumper $obj;
#
# It can get seriously annoying, so why 
# not just do this ...
sub dump { 
    my $self = shift;
    require Data::Dumper;
    local $Data::Dumper::Maxdepth = shift || 1;
    Data::Dumper::Dumper $self;
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
    --(is a subclass of)--->

A deeper discussion of this model is currently beyond the scope of 
this documenation. 
  
=head1 METHODS

=over 4

=item B<meta>

=item B<dump (?$max_depth)>

This will C<require> the L<Data::Dumper> module and then dump a 
representation of your object. It passed the C<$max_depth> arg 
to C<$Data::Dumper::Maxdepth>. The default C<$max_depth> is 1, 
so it will not go crazy and print a massive bunch of stuff. 
Adjust this as nessecary.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
