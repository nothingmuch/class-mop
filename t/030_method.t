#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');    
    use_ok('Class::MOP::Method');
}

my $meta = Class::MOP::Method->meta;
isa_ok($meta, 'Class::MOP::Class');


{
    my $meta = Class::MOP::Method->meta();
    isa_ok($meta, 'Class::MOP::Class');
    
    foreach my $method_name (qw(
        meta 
        wrap
        )) {
        ok($meta->has_method($method_name), '... Class::MOP::Method->has_method(' . $method_name . ')');
    }
}

dies_ok {
    Class::MOP::Method->wrap()
} '... bad args for &wrap';

dies_ok {
    Class::MOP::Method->wrap('Fail')
} '... bad args for &wrap';

dies_ok {
    Class::MOP::Method->wrap([])
} '... bad args for &wrap';