use strict;
use warnings;

use Test::More tests => 5;

{
    package Foo;
    use metaclass;

    use Scalar::Util qw(blessed);

    no warnings 'once';
    *a_glob_assignment = \&Scalar::Util::blessed;

    sub a_declared_method { }

    Class::MOP::Class->initialize(__PACKAGE__)->add_method("an_added_method" => sub {});
}

my @warnings;

{
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    Class::MOP::Class->initialize("Foo")->warn_on_symbol_pollution();
}

is( scalar(@warnings), 1, "warning generated" );

my $warning = $warnings[0];

like( $warning, qr/blessed/, "mentions import" );
like( $warning, qr/a_glob_assignment/, "mentions glob assignment" );
unlike( $warning, qr/a_declared_method/, "doesn't mention normal method" );
unlike( $warning, qr/an_added_method/, "doesn't mention a manually installed method" );


