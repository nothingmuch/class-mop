use strict;
use warnings;

use Test::More;

plan tests => 1;

use Class::MOP;


{
    package Foo;

    my $meta = Class::MOP::Class->initialize(__PACKAGE__);

    $@ = 'dollar at';

    $meta->make_immutable;

    ::is( $@, 'dollar at', '$@ is untouched after immutablization' );
}
