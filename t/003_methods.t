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
    *baz = \&bar;
    
    # We hateses the "used only once" warnings
    { my $temp = \&Foo::baz }

    package main;
    
    sub Foo::blah { $_[0]->Foo::baz() }
    
    {
        no strict 'refs';
        *{'Foo::bling'} = sub { '$$Bling$$' };
        *{'Foo::bang'} = Sub::Name::subname 'Foo::bang' => sub { '!BANG!' };        
    }
}

my $Foo = Foo->meta;

my $foo = sub { 'Foo::foo' };

lives_ok {
    $Foo->add_method('foo' => $foo);
} '... we added the method successfully';

ok($Foo->has_method('foo'), '... Foo->has_method(foo) (defined with Sub::Name)');
ok(!$Foo->has_method('blessed'), '... !Foo->has_method(blessed) (imported into Foo)');
ok($Foo->has_method('bar'), '... Foo->has_method(bar) (defined in Foo)');
ok($Foo->has_method('baz'), '... Foo->has_method(baz) (typeglob aliased within Foo)');
ok($Foo->has_method('blah'), '... Foo->has_method(blah) (defined in main:: using fully qualified package name)');
ok(!$Foo->has_method('bling'), '... !Foo->has_method(bling) (defined in main:: using symbol tables (no Sub::Name))');
ok($Foo->has_method('bang'), '... Foo->has_method(bang) (defined in main:: using symbol tables and Sub::Name)');

is($Foo->get_method('foo'), $foo, '... Foo->get_method(foo) == \&foo');

is(Foo->foo(), 'Foo::foo', '... Foo->foo() returns "Foo::foo"');
is(Foo->bar(), 'Foo::bar', '... Foo->bar() returns "Foo::bar"');
is(Foo->baz(), 'Foo::bar', '... Foo->baz() returns "Foo::bar" (because it is aliased to &bar)');
