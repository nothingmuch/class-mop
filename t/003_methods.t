#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');   
    use_ok('Class::MOP::Class');        
}

{   
    package Foo;
    
    # import a sub
    use Scalar::Util 'blessed'; 
    
    # define a sub in package
    sub bar { 'Foo::bar' } 
}

my $Foo = Foo->meta;

my $foo = sub { 'Foo::foo' };

lives_ok {
    $Foo->add_method('foo' => $foo);
} '... we added the method successfully';

ok($Foo->has_method('foo'), '... Foo->has_method(foo) (defined with Sub::Name)');
ok(!$Foo->has_method('blessed'), '... !Foo->has_method(blessed) (imported into Foo)');
ok($Foo->has_method('bar'), '... Foo->has_method(bar) (defined in Foo)');

is($Foo->get_method('foo'), $foo, '... Foo->get_method(foo) == \&foo');

is(Foo->foo(), 'Foo::foo', '... Foo->foo() returns "Foo::foo"');