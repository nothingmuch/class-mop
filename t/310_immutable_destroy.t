use strict;
use warnings;
use Test::More tests => 1;
use Class::MOP;

BEGIN {
	package FooBar;
	sub DESTROY { shift->name }
}

{
	my $meta = Class::MOP::Class->initialize('FooBar');
	$meta->add_attribute(
		Class::MOP::Attribute->new(
			'name' => (
				reader => 'name',
			)
		)
	);

    $meta->make_immutable(
		inline_accessors => 1,
		inline_constructor => 1,
		inline_destructor => 1,
	);
}

my $f = FooBar->new( name => 'SUSAN' );

is( $f->DESTROY, 'SUSAN', 'Did class-mop overload DESTROY?' );
