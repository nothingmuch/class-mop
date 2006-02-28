#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 18;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');    
    use_ok('Class::MOP::Method');
}

# test before and afters
{
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
}

# test around method
{
	my $method = Class::MOP::Method->new(sub { 4 });
	isa_ok($method, 'Class::MOP::Method');
	
	is($method->(), 4, '... got the right value from the wrapped method');	

	my $wrapped = $method->wrap;
	isa_ok($wrapped, 'Class::MOP::Method');

	is($wrapped->(), 4, '... got the right value from the wrapped method');
	
	lives_ok {
		$wrapped->add_around_modifier(sub { (3, $_[0]->()) });		
		$wrapped->add_around_modifier(sub { (2, $_[0]->()) });
		$wrapped->add_around_modifier(sub { (1, $_[0]->()) });		
	} '... added the around modifier okay';	

	is_deeply(
		[ $wrapped->() ],
		[ 1, 2, 3, 4 ],
		'... got the right results back from the around methods');
}





