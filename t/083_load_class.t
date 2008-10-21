#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 27;
use Test::Exception;

require Class::MOP;
use lib 't/lib';

ok(!Class::MOP::is_class_loaded(), "is_class_loaded with no argument returns false");
ok(!Class::MOP::is_class_loaded(''), "can't load the empty class");
ok(!Class::MOP::is_class_loaded(\"foo"), "can't load a class name reference??");

ok(!Class::MOP::_is_valid_class_name(undef), 'undef is not a valid class name');
ok(!Class::MOP::_is_valid_class_name(''), 'empty string is not a valid class name');
ok(!Class::MOP::_is_valid_class_name(\"foo"), 'a reference is not a valid class name');
ok(!Class::MOP::_is_valid_class_name('bogus name'), q{'bogus name' is not a valid class name});
ok(Class::MOP::_is_valid_class_name('Foo'), q{'Foo' is a valid class name});
ok(Class::MOP::_is_valid_class_name('Foo::Bar'), q{'Foo::Bar' is a valid class name});
ok(Class::MOP::_is_valid_class_name('Foo_::Bar2'), q{'Foo_::Bar2' is a valid class name});
throws_ok { Class::MOP::load_class('bogus name') } qr/Invalid class name \(bogus name\)/;

throws_ok {
    Class::MOP::load_class('__PACKAGE__')
} qr/__PACKAGE__\.pm.*\@INC/, 'errors sanely on __PACKAGE__.pm';

my $meta = Class::MOP::load_class('BinaryTree');
ok($meta, "successfully loaded the class BinaryTree");
is($meta->name, "BinaryTree", "load_class returns the metaclass");
can_ok('BinaryTree' => 'traverse');

do {
    package Class;
    sub method {}
};


my $ret = Class::MOP::load_class('Class');
ok($ret, "this should not die!");
is( $ret, "Class", "class name returned" );

ok( !Class::MOP::does_metaclass_exist("Class"), "no metaclass for non MOP class" );

throws_ok {
    Class::MOP::load_class('FakeClassOhNo');
} qr/Can't locate /;

throws_ok {
    Class::MOP::load_class('SyntaxError');
} qr/Missing right curly/;

{
    package Other;
    use constant foo => "bar";
}

lives_ok {
    ok(Class::MOP::is_class_loaded("Other"), 'is_class_loaded(Other)');
}
"a class with just constants is still a class";

{
    package Lala;
    use metaclass;
}

isa_ok( Class::MOP::load_class("Lala"), "Class::MOP::Class", "when an object has a metaclass it is returned" );

lives_ok {
    isa_ok(Class::MOP::load_one_class_of("Lala", "Does::Not::Exist"), "Class::MOP::Class", 'Load_classes first param ok, metaclass returned');
    isa_ok(Class::MOP::load_one_class_of("Does::Not::Exist", "Lala"), "Class::MOP::Class", 'Load_classes second param ok, metaclass returned');
} 'load_classes works';
throws_ok {
    Class::MOP::load_one_class_of("Does::Not::Exist", "Also::Does::Not::Exist")
} qr/Could not load class \(Does::Not::Exist.*Could not load class \(Also::Does::Not::Exist/s, 'Multiple non-existant classes cause exception';


