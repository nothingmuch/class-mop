#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 19;

BEGIN { 
    use_ok('Class::MOP');    
    use_ok('examples::InsideOutClass');
}

{
    package Foo;
    
    sub meta { InsideOutClass->initialize($_[0]) }
    
    Foo->meta->add_attribute(
        InsideOutClass::Attribute->new('foo' => (
            accessor  => 'foo',
            predicate => 'has_foo',
        ))
    );
    
    Foo->meta->add_attribute(
        InsideOutClass::Attribute->new('bar' => (
            reader  => 'get_bar',
            writer  => 'set_bar',
            default => 'FOO is BAR'            
        ))
    );    
    
    sub new  {
        my $class = shift;
        bless $class->meta->construct_instance() => $class;
    }
}

my $foo = Foo->new();
isa_ok($foo, 'Foo');

can_ok($foo, 'foo');
can_ok($foo, 'has_foo');
can_ok($foo, 'get_bar');
can_ok($foo, 'set_bar');

ok(!$foo->has_foo, '... Foo::foo is not defined yet');
is($foo->foo(), undef, '... Foo::foo is not defined yet');
is($foo->get_bar(), 'FOO is BAR', '... Foo::bar has been initialized');

$foo->foo('This is Foo');

ok($foo->has_foo, '... Foo::foo is defined now');
is($foo->foo(), 'This is Foo', '... Foo::foo == "This is Foo"');

$foo->set_bar(42);
is($foo->get_bar(), 42, '... Foo::bar == 42');

my $foo2 = Foo->new();
isa_ok($foo2, 'Foo');

ok(!$foo2->has_foo, '... Foo2::foo is not defined yet');
is($foo2->foo(), undef, '... Foo2::foo is not defined yet');
is($foo2->get_bar(), 'FOO is BAR', '... Foo2::bar has been initialized');

$foo2->set_bar('DONT PANIC');
is($foo2->get_bar(), 'DONT PANIC', '... Foo2::bar == DONT PANIC');

is($foo->get_bar(), 42, '... Foo::bar == 42');
