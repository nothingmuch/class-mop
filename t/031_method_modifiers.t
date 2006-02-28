#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 18;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');    
    use_ok('Class::MOP::Method');
}

my $trace = '';

my $method = Class::MOP::Method->new(sub { $trace .= 'primary' });
isa_ok($method, 'Class::MOP::Method');

$method->();
is($trace, 'primary', '... got the right return value from method');
$trace = '';

my $wrapped = $method->wrap();
isa_ok($wrapped, 'Class::MOP::Method');

$wrapped->();
is($trace, 'primary', '... got the right return value from the wrapped method');
$trace = '';

lives_ok {
	$wrapped->add_before_modifier(sub { $trace .= 'before -> ' });
} '... added the before modifier okay';

$wrapped->();
is($trace, 'before -> primary', '... got the right return value from the wrapped method (w/ before)');
$trace = '';

lives_ok {
	$wrapped->add_after_modifier(sub { $trace .= ' -> after' });
} '... added the after modifier okay';

$wrapped->();
is($trace, 'before -> primary -> after', '... got the right return value from the wrapped method (w/ before)');
$trace = '';