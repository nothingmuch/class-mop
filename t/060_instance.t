#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 25;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP::Instance');    
}

can_ok( "Class::MOP::Instance", $_ ) for qw/
    new 
    
	create_instance
	bless_instance_structure

    get_all_slots

	get_slot_value
	set_slot_value

	inline_get_slot_value
	inline_set_slot_value
/;

{
	package Foo;
	use metaclass;
	
	Foo->meta->add_attribute('moosen');

	package Bar;
	use metaclass;
	use base qw/Foo/;

	Bar->meta->add_attribute('elken');
}

my $mi_foo = Foo->meta->get_meta_instance;
isa_ok($mi_foo, "Class::MOP::Instance");

is_deeply(
    [ $mi_foo->get_all_slots ], 
    [ "moosen" ], 
    '... get all slots for Foo');

my $mi_bar = Bar->meta->get_meta_instance;
isa_ok($mi_bar, "Class::MOP::Instance");

isnt($mi_foo, $mi_bar, '... they are not the same instance');

is_deeply(
    [ sort $mi_bar->get_all_slots ], 
    [ "elken", "moosen" ], 
    '... get all slots for Bar');

my $i_foo = $mi_foo->create_instance;
isa_ok($i_foo, "Foo");

{
    my $i_foo_2 = $mi_foo->create_instance;
    isa_ok($i_foo_2, "Foo");    
    isnt($i_foo_2, $i_foo, '... not the same instance');
    is_deeply($i_foo, $i_foo_2, '... but the same structure');
}

ok(!defined($mi_foo->get_slot_value( $i_foo, "moosen" )), "... no value for slot");

$mi_foo->set_slot_value( $i_foo, "moosen", "the value" );

is($mi_foo->get_slot_value( $i_foo, "moosen" ), "the value", "... get slot value");

ok(!$i_foo->can('moosen'), '... Foo cant moosen');

eval 'sub Foo::moosen { ' . $mi_foo->inline_get_slot_value( '$_[0]', 'moosen' ) . ' }';
ok(!$@, "compilation of inline get value had no error");

can_ok($i_foo, 'moosen');

is($i_foo->moosen, "the value", "... inline get value worked");

$mi_foo->set_slot_value( $i_foo, "moosen", "the other value" );

is($i_foo->moosen, "the other value", "... inline get value worked (even after value is changed)");
