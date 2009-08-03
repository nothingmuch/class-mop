#!perl -w
use strict;
use Benchmark qw(:all);

my($count, $module) = @ARGV;
$count  ||= 10;
$module ||= 'Moose';

cmpthese timethese $count => {
    released => sub {
        system( $^X, '-e', "require $module" ) == 0 or die;
    },
    blead => sub {
        system( $^X, '-Iblib/lib', '-Iblib/arch', '-e', "require $module" )
            == 0
            or die;
    },
};
