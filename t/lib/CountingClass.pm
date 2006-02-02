
package CountingClass;

use strict;
use warnings;

use Class::MOP 'meta';

our $VERSION = '0.01';

__PACKAGE__->meta->superclasses('Class::MOP::Class');

__PACKAGE__->meta->add_attribute(
    Class::MOP::Attribute->new('$:count' => (
        reader  => 'get_count',
        default => 0
    ))
);

sub construct_instance {
    my ($class, %params) = @_;
    $class->{'$:count'}++;
    return $class->SUPER::construct_instance();
}

1;