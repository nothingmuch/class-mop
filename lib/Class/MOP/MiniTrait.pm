package Class::MOP::MiniTrait;

use strict;
use warnings;

use Scalar::Util 'blessed';

our $VERSION   = '0.95';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

sub apply {
    my $class = shift;
    my $meta  = shift;

    die "The Class::MOP::MiniTrait->apply() method expects a metaclass object"
        unless $meta && blessed $meta && $meta->isa('Class::MOP::Class');

    for my $meth_name ( $class->meta->get_method_list ) {
        my $meth = $class->meta->get_method($meth_name);

        if ( $meta->find_method_by_name($meth_name) ) {
            $meta->add_around_method_modifier( $meth_name, $meth->body );
        }
        else {
            $meta->add_method( $meth_name, $meth->clone );
        }
    }
}

1;
