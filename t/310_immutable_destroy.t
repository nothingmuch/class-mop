use strict;
use warnings;
use Test::More tests => 2;
use Class::MOP;

SKIP: {
    unless (eval { require Moose; Moose->VERSION(0.72); 1 }) {
        diag( $@ );
        skip 'This test requires Moose 0.72', 2;
        exit 0;
    }

    {
        local $SIG{__WARN__} = sub {};
        eval <<'EOF';
    package FooBar;
    use Moose 0.72;

    has 'name' => ( is => 'ro' );

    sub DESTROY { shift->name }

    __PACKAGE__->meta->make_immutable;
EOF
    }

    ok( ! $@, 'evaled FooBar package' )
      or diag( $@ );
    my $f = FooBar->new( name => 'SUSAN' );

    is( $f->DESTROY, 'SUSAN',
        'Class::MOP::Class should not override an existing DESTROY method' );
}
