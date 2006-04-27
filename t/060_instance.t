#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 30;
use Test::Exception;

use Scalar::Util 'reftype', 'isweak';

BEGIN {
    use_ok('Class::MOP::Instance');    
}

can_ok( "Class::MOP::Instance", $_ ) for qw/
	create_instance
	bless_instance_structure

	add_slot
	remove_slot
	get_all_slots
	get_all_slots_recursively
	has_slot
	has_slot_recursively
	get_all_parents

	get_slot_value
	set_slot_value
	slot_initialized
	initialize_slot
	set_slot_value_with_init

	inline_get_slot_value
	inline_set_slot_value
	inline_initialize_slot
	inline_set_slot_value_with_init
/;

{
	package Foo;
	use metaclass;

	package Bar;
	use metaclass;
	use base qw/Foo/;
}

isa_ok( my $mi_foo = Foo->meta->get_meta_instance, "Class::MOP::Instance" );

$mi_foo->add_slot("moosen");

is_deeply( [ $mi_foo->get_all_slots ], [ "moosen" ], "get slots" );


my $mi_bar = Bar->meta->get_meta_instance;

is_deeply( [ $mi_bar->get_all_slots ], [], "get slots" );
is_deeply( [ $mi_bar->get_all_slots_recursively ], ["moosen"], "get slots rec" );

$mi_bar->add_slot("elken");

is_deeply( [ sort $mi_bar->get_all_slots_recursively ], [qw/elken moosen/], "get slots rec" );

isa_ok( my $i_foo = $mi_foo->create_instance, "Foo" );

ok( !$mi_foo->get_slot_value( $i_foo, "moosen" ), "no value for slot");

$mi_foo->initialize_slot( $i_foo, "moosen" );
$mi_foo->set_slot_value( $i_foo, "moosen", "the value" );

is ( $mi_foo->get_slot_value( $i_foo, "moosen" ), "the value", "get slot value" );

eval 'sub Foo::moosen { ' . $mi_foo->inline_get_slot_value( '$_[0]', '"moosen"' ) . ' }';
ok( !$@, "compilation of inline get value had no error" );

is( $i_foo->moosen, "the value", "inline get value" );

$mi_foo->set_slot_value( $i_foo, "moosen", "the other value" );

is( $i_foo->moosen, "the other value", "inline get value");
