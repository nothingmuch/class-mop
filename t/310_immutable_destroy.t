use strict;
use warnings;
use Test::More tests => 1;
use Class::MOP;

SKIP: {
    unless (eval { require Moose; 1 }) {
        skip 'This test requires Moose', 1;
        exit 0;
    }

    {
        local $SIG{__WARN__} = sub {};
        eval <<'EOF';
    package FooBar;
    use Moose;

    has 'name' => ( is => 'ro' );

    sub DESTROY { shift->name }

    __PACKAGE__->meta->make_immutable;
EOF
    }

    my $f = FooBar->new( name => 'SUSAN' );

    is( $f->DESTROY, 'SUSAN',
        'Class::MOP::Class should not override an existing DESTROY method' );
}
