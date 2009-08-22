use strict;
use warnings;

use Test::More tests => 4;
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

