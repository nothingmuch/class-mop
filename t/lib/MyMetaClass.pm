
package MyMetaClass;

use strict;
use warnings;

use base 'Class::MOP::Class';

sub mymetaclass_attributes{
  my $self = shift;
  return grep { $_->isa("MyMetaClass::Attribute") }
    $self->compute_all_applicable_attributes;
}

1;
