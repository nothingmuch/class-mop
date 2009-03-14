use strict;
use warnings;

use Test::More tests => 5;
use Sub::Name 'subname';

BEGIN {
    $^P &= ~0x200; # Don't munge anonymous sub names
}

use Class::MOP;


sub code_name_is {
    my ( $code, $stash, $name ) = @_;

    is_deeply(
        [ Class::MOP::get_code_info($code) ],
        [ $stash, $name ],
        "sub name is ${stash}::$name"
    );
}

code_name_is( sub {}, main => "__ANON__" );

code_name_is( subname("Foo::bar", sub {}), Foo => "bar" );

code_name_is( subname("", sub {}), "main" => "" );

require Class::MOP::Method;
code_name_is( \&Class::MOP::Method::name, "Class::MOP::Method", "name" );

{
    package Foo;

    sub MODIFY_CODE_ATTRIBUTES {
        my ($class, $code) = @_;
        ::ok(!Class::MOP::get_code_info($code), "no name for a coderef that's still compiling");
        return ();
    }

    sub foo : Bar {}
}
