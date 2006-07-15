#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';
use Test::Deep;

BEGIN {
    use_ok("Class::MOP::Iterator");
}

my @lists = ( [ ], [qw/foo bar gorch/], [undef, 0, 1] );

foreach my $list ( @lists ) {
    is_deeply(
        [ Class::MOP::Iterator->from_list(@$list)->all ],
        $list,
        "from list round trips",
    );

    foreach my $filter ( sub { defined($_) }, sub { $_ }, sub { no warnings 'uninitialized'; /foo/ }, sub { 0 } ) {
        is_deeply(
            [ Class::MOP::Iterator->grep( $filter, Class::MOP::Iterator->from_list(@$list) )->all ],
            [ grep { $filter->() } @$list ],
            "grep iterator vs list is the same",
        );
    }

    foreach my $map ( sub { 42 }, sub { [$_] } ) {
        is_deeply(
            [ Class::MOP::Iterator->map( $map, Class::MOP::Iterator->from_list(@$list) )->all ],
            [ map { $map->() } @$list ],
            "map iterator vs list is the same",
        );
    }

    is_deeply(
        [ Class::MOP::Iterator->cons( "foo", Class::MOP::Iterator->from_list(@$list) )->all ],
        [ "foo", @$list ],
        "cons",
    );

}

my @iters = map { Class::MOP::Iterator->from_list(@$_) } @lists;

is_deeply(
    [ Class::MOP::Iterator->concat( @iters )->all ],
    [ map { @$_ } @lists ],
    "concat",
);

# the hard way to concat ;-)
is_deeply(
    [ Class::MOP::Iterator->flatten(
        Class::MOP::Iterator->map(
            sub { Class::MOP::Iterator->from_list(@$_) },
            Class::MOP::Iterator->from_list(@lists),
        )
    )->all ],
    [ map { @$_ } @lists ],
    "flatten",
);

