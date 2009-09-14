use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;

use Carp;

$SIG{__WARN__} = \&croak;

{
    package Foo;
    use Test::More;
    use Test::Exception;

    throws_ok {
        Class::MOP::in_global_destruction();
    } qr/\b deprecated \b/xmsi, 'complained';
}

{
    package Bar;
    use Test::More;
    use Test::Exception;

    use Class::MOP::Deprecated -compatible => 0.93;

    throws_ok {
        Class::MOP::in_global_destruction();
    } qr/\b deprecated \b/xmsi, 'complained';
}

{
    package Baz;
    use Test::More;
    use Test::Exception;

    use Class::MOP::Deprecated -compatible => 0.92;

    lives_ok {
        Class::MOP::in_global_destruction();
    } 'safe';
}


{
    package Baz::Inner;
    use Test::More;
    use Test::Exception;

    lives_ok {
        Class::MOP::in_global_destruction();
    } 'safe in an inner class';
}

{
    package Quux;

    use Class::MOP::Deprecated -compatible => 0.92;
    use Scalar::Util qw( blessed );

    use metaclass;

    sub foo {42}

    Quux->meta->add_method( bar => sub {84} );

    my $map = Quux->meta->get_method_map;
    my @method_objects = grep { blessed($_) } values %{$map};

    ::is( scalar @method_objects, 3,
          'get_method_map still returns all values as method object' );
    ::is_deeply( [ sort keys %{$map} ],
                 [ qw( bar foo meta ) ],
                 'get_method_map returns expected methods' );
}
