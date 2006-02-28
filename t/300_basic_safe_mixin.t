#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::SafeMixin');
}

## Mixin a class without a superclass.
{
    package FooMixin;   
    sub foo { 'FooMixin::foo' }    

    package Foo;
    use metaclass 'Class::MOP::SafeMixin';
    Foo->meta->mixin('FooMixin');
    sub new { (shift)->meta->new_object(@_) }
}

my $foo = Foo->new();
isa_ok($foo, 'Foo');

can_ok($foo, 'foo');
is($foo->foo, 'FooMixin::foo', '... got the right value from the mixin method');

## Mixin a class who shares a common ancestor
{   
    package Baz;
    our @ISA = ('Foo');    
    sub baz { 'Baz::baz' }    	

    package Bar;
    our @ISA = ('Foo');

    package Foo::Baz;
    our @ISA = ('Foo');    
	eval { Foo::Baz->meta->mixin('Baz') };
	::ok(!$@, '... the classes superclass must extend a subclass of the superclass of the mixins');

}

my $foo_baz = Foo::Baz->new();
isa_ok($foo_baz, 'Foo::Baz');
isa_ok($foo_baz, 'Foo');

can_ok($foo_baz, 'baz');
is($foo_baz->baz(), 'Baz::baz', '... got the right value from the mixin method');

{
	package Foo::Bar;
    our @ISA = ('Foo', 'Bar');	

    package Foo::Bar::Baz;
    our @ISA = ('Foo::Bar');    
	eval { Foo::Bar::Baz->meta->mixin('Baz') };
	::ok(!$@, '... the classes superclass must extend a subclass of the superclass of the mixins');
}

my $foo_bar_baz = Foo::Bar::Baz->new();
isa_ok($foo_bar_baz, 'Foo::Bar::Baz');
isa_ok($foo_bar_baz, 'Foo::Bar');
isa_ok($foo_bar_baz, 'Foo');
isa_ok($foo_bar_baz, 'Bar');

can_ok($foo_bar_baz, 'baz');
is($foo_bar_baz->baz(), 'Baz::baz', '... got the right value from the mixin method');

