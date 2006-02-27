#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::SafeMixin');
}

{
    package FooMixin;   
	use metaclass;
	
	my %cache;
	sub MODIFY_CODE_ATTRIBUTES {
		my ($class, $code, @attrs) = @_;
		::diag join ", " => $code, "Attrs: ", @attrs;
		$cache{$code} = $attrs[0];
		return ();	
	}	
	
	sub FETCH_CODE_ATTRIBUTES { $cache{$_[1]} }
	
    sub foo : before { 'FooMixin::foo::before -> ' }    
    sub bar : after  { ' -> FooMixin::bar::after'  }    
    sub baz : around { 
		my $method = shift;
		my ($self, @args) = @_;
		'FooMixin::baz::around(' . $self->$method(@args) . ')'; 
	}            

    package Foo;
    use metaclass 'Class::MOP::SafeMixin';

    Foo->meta->mixin('FooMixin');
    
    sub new { (shift)->meta->new_object(@_) }
    
    sub foo { 'Foo::foo' }
    sub bar { 'Foo::bar' }
    sub baz { 'Foo::baz' }        
}

diag attributes::get(\&FooMixin::foo) . "\n";

my $foo = Foo->new();
isa_ok($foo, 'Foo');

is($foo->foo(), 'FooMixin::foo::before -> Foo::foo', '... before method worked');
is($foo->bar(), 'Foo::bar -> FooMixin::bar::after', '... after method worked');
is($foo->baz(), 'FooMixin::baz::around(Foo::baz)', '... around method worked');




