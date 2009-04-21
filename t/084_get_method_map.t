use strict;
use warnings;

use Test::More tests => 11;


{
    package Foo;

    use metaclass;

    sub foo { }
}

{
    my $map = Foo->meta->get_method_map;

    is( scalar keys %{$map}, 2,
        'method map for Foo has two key' );
    ok( $map->{foo}, '... has a foo method in the map' );
    ok( $map->{meta}, '... has a meta method in the map' );
}


Foo->meta->add_method( bar => sub { } );

{
    my $map = Foo->meta->get_method_map;

    is( scalar keys %{$map}, 3,
        'method map for Foo has three keys' );
    ok( $map->{foo}, '... has a foo method in the map' );
    ok( $map->{bar}, '... has a bar method in the map' );
    ok( $map->{meta}, '... has a meta method in the map' );
}

# Tests a bug where after a metaclass object was recreated, methods
# added via add_method were not showing up in the map, but only with
# the non-XS version of the code.
Class::MOP::remove_metaclass_by_name('Foo');

{
    my $map = Foo->meta->get_method_map;

    is( scalar keys %{$map}, 3,
        'method map for Foo has three keys' );
    ok( $map->{foo}, '... has a foo method in the map' );
    ok( $map->{bar}, '... has a bar method in the map' );
    ok( $map->{meta}, '... has a meta method in the map' );
}
