#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 30;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');   
    use_ok('Class::MOP::Class');        
}

{   
    package Foo;
    use metaclass;
    our $VERSION = '0.01';
    
    package Bar;
    our @ISA = ('Foo');
}

my $Foo = Foo->meta;
isa_ok($Foo, 'Class::MOP::Class');

my $Bar = Bar->meta;
isa_ok($Bar, 'Class::MOP::Class');

is($Foo->name, 'Foo', '... Foo->name == Foo');
is($Bar->name, 'Bar', '... Bar->name == Bar');

is($Foo->version, '0.01', '... Foo->version == 0.01');
is($Bar->version, undef, '... Bar->version == undef');

is_deeply([$Foo->superclasses], [], '... Foo has no superclasses');
is_deeply([$Bar->superclasses], ['Foo'], '... Bar->superclasses == (Foo)');

isa_ok( scalar($Foo->superclasses), "Class::MOP::Iterator" );
is_deeply( [ $Foo->superclasses->all ], [], "no superclasses" );

isa_ok( scalar($Bar->superclasses), "Class::MOP::Iterator" );
is_deeply( [ $Bar->superclasses->all ], ['Foo'], "Bar superclasses in iter" );

$Foo->superclasses('UNIVERSAL');

is_deeply([$Foo->superclasses], ['UNIVERSAL'], '... Foo->superclasses == (UNIVERSAL) now');

is_deeply(
    [ $Foo->class_precedence_list ], 
    [ 'Foo', 'UNIVERSAL' ], 
    '... Foo->class_precedence_list == (Foo, UNIVERSAL)');

is_deeply(
    [ $Bar->class_precedence_list ], 
    [ 'Bar', 'Foo', 'UNIVERSAL' ], 
    '... Bar->class_precedence_list == (Bar, Foo, UNIVERSAL)');

my $i = $Bar->class_precedence_list;

ok( !$i->is_done, "iterator not done" );
is( $i->next, 'Bar', "next class in iterator" );
ok( !$i->is_done, "iterator not done" );
is( $i->next, 'Foo', "next class in iterator" );
ok( !$i->is_done, "iterator not done" );
is( $i->next, 'UNIVERSAL', "next class in iterator" );
ok( $i->is_done, "iterator done" );

# create a class using Class::MOP::Class ...

my $Baz = Class::MOP::Class->create(
            'Baz' => '0.10' => (
                superclasses => [ 'Bar' ]
            ));
isa_ok($Baz, 'Class::MOP::Class');
is(Baz->meta, $Baz, '... our metaclasses are singletons');

is($Baz->name, 'Baz', '... Baz->name == Baz');
is($Baz->version, '0.10', '... Baz->version == 0.10');

is_deeply([$Baz->superclasses], ['Bar'], '... Baz->superclasses == (Bar)');

is_deeply(
    [ $Baz->class_precedence_list ], 
    [ 'Baz', 'Bar', 'Foo', 'UNIVERSAL' ], 
    '... Baz->class_precedence_list == (Baz, Bar, Foo, UNIVERSAL)');

