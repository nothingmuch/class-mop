use strict;
use warnings;
use Test::More tests => 1;
use Class::MOP;

BEGIN { 
	if (not Class::MOP::load_class('Moose::Object')) {
		skip 'test requires moose', 1;
		exit 0;
	}
}


{
    package FooBar;
    use Moose;

    has 'name' => ( is => 'ro' );

    sub DESTROY { shift->name }

    __PACKAGE__->meta->make_immutable;
}

my $f = FooBar->new( name => 'SUSAN' );

is( $f->DESTROY, 'SUSAN', 'Did moose overload DESTROY?' );
