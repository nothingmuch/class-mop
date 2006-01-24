#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');   
    use_ok('Class::MOP::Class');        
}

{   # This package tries to test &has_method 
    # as exhaustively as possible. More corner
    # cases are welcome :)
    package Foo;
    
    # import a sub
    use Scalar::Util 'blessed'; 
    
    use constant FOO_CONSTANT => 'Foo-CONSTANT';
    
    # define a sub in package
    sub bar { 'Foo::bar' } 
    *baz = \&bar;

    { # method named with Sub::Name inside the package scope
        no strict 'refs';
        *{'Foo::floob'} = Sub::Name::subname 'floob' => sub { '!floob!' }; 
    }

    # We hateses the "used only once" warnings
    { my $temp = \&Foo::baz }

    package main;
    
    sub Foo::blah { $_[0]->Foo::baz() }
    
    {
        no strict 'refs';
        *{'Foo::bling'} = sub { '$$Bling$$' };
        *{'Foo::bang'} = Sub::Name::subname 'Foo::bang' => sub { '!BANG!' }; 
        *{'Foo::boom'} = Sub::Name::subname 'boom' => sub { '!BOOM!' };     
        
        eval "package Foo; sub evaled_foo { 'Foo::evaled_foo' }";           
    }
}

my $Foo = Class::MOP::Class->initialize('Foo');

my $foo = sub { 'Foo::foo' };

lives_ok {
    $Foo->add_method('foo' => $foo);
} '... we added the method successfully';

ok($Foo->has_method('foo'), '... Foo->has_method(foo) (defined with Sub::Name)');

is($Foo->get_method('foo'), $foo, '... Foo->get_method(foo) == \&foo');
is(Foo->foo(), 'Foo::foo', '... Foo->foo() returns "Foo::foo"');

# now check all our other items ...

ok($Foo->has_method('FOO_CONSTANT'), '... Foo->has_method(FOO_CONSTANT) (defined w/ use constant)');
ok($Foo->has_method('bar'), '... Foo->has_method(bar) (defined in Foo)');
ok($Foo->has_method('baz'), '... Foo->has_method(baz) (typeglob aliased within Foo)');
ok($Foo->has_method('floob'), '... Foo->has_method(floob) (defined in Foo:: using symbol tables and Sub::Name w/out package name)');
ok($Foo->has_method('blah'), '... Foo->has_method(blah) (defined in main:: using fully qualified package name)');
ok($Foo->has_method('bling'), '... Foo->has_method(bling) (defined in main:: using symbol tables (no Sub::Name))');
ok($Foo->has_method('bang'), '... Foo->has_method(bang) (defined in main:: using symbol tables and Sub::Name)');
ok($Foo->has_method('evaled_foo'), '... Foo->has_method(evaled_foo) (evaled in main::)');

ok(!$Foo->has_method('blessed'), '... !Foo->has_method(blessed) (imported into Foo)');
ok(!$Foo->has_method('boom'), '... !Foo->has_method(boom) (defined in main:: using symbol tables and Sub::Name w/out package name)');

ok(!$Foo->has_method('not_a_real_method'), '... !Foo->has_method(not_a_real_method) (does not exist)');
is($Foo->get_method('not_a_real_method'), undef, '... Foo->get_method(not_a_real_method) == undef');

# ... test our class creator 

my $Bar = Class::MOP::Class->create(
            'Bar' => '0.10' => (
                methods => {
                    foo => sub { 'Bar::foo' },
                    bar => sub { 'Bar::bar' },                    
                }
            ));
isa_ok($Bar, 'Class::MOP::Class');

ok($Bar->has_method('foo'), '... Bar->has_method(foo)');
ok($Bar->has_method('bar'), '... Bar->has_method(bar)');

is(Bar->foo, 'Bar::foo', '... Bar->foo == Bar::foo');
is(Bar->bar, 'Bar::bar', '... Bar->bar == Bar::bar');

lives_ok {
    $Bar->add_method('foo' => sub { 'Bar::foo v2' });
} '... overwriting a method is fine';

ok($Bar->has_method('foo'), '... Bar-> (still) has_method(foo)');
is(Bar->foo, 'Bar::foo v2', '... Bar->foo == "Bar::foo v2"');
