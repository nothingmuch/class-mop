#!perl -w
use strict;
use Benchmark qw(:all);

my $module = 'Moose';

cmpthese timethese 10 => {
    released => sub {
        system( $^X, '-e', "require $module" ) == 0 or die;
    },
    blead => sub {
        system( $^X, '-Iblib/lib', '-Iblib/arch', '-e', "require $module" )
            == 0
            or die;
    },
};
