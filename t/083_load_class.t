#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 19;
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

my $meta = Class::MOP::load_class('BinaryTree');
ok($meta, "successfully loaded the class BinaryTree");
is($meta->name, "BinaryTree", "load_class returns the metaclass");
can_ok('BinaryTree' => 'traverse');

do {
    package Class;
    sub method {}
};

ok(Class::MOP::load_class('Class'), "this should not die!");

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
