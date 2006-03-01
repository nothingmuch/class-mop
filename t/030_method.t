#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 18;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');    
    use_ok('Class::MOP::Method');
}

my $method = Class::MOP::Method->wrap(sub { 1 });
is($method->meta, Class::MOP::Method->meta, '... instance and class both lead to the same meta');

is($method->package_name, 'main', '... our package is main::');
is($method->name, '__ANON__', '... our sub name is __ANON__');

my $meta = Class::MOP::Method->meta;
isa_ok($meta, 'Class::MOP::Class');

foreach my $method_name (qw(
    wrap
	package_name
	name
    )) {
    ok($meta->has_method($method_name), '... Class::MOP::Method->has_method(' . $method_name . ')');
	my $method = $meta->get_method($method_name);
	is($method->package_name, 'Class::MOP::Method', '... our package is Class::MOP::Method');
	is($method->name, $method_name, '... our sub name is "' . $method_name . '"');	
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