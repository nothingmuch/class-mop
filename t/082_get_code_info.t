use strict;
use warnings;

use Test::More tests => 6;
use Sub::Name 'subname';

BEGIN {
    $^P &= ~0x200; # Don't munger anonymous sub names
}

BEGIN { use_ok("Class::MOP") }


sub code_name_is ($$$;$) {
    my ( $code, $stash, $name, $desc ) = @_;
    $desc ||= "sub name is ${stash}::$name";

    is_deeply(
        [ Class::MOP::get_code_info($code) ],
        [ $stash, $name ],
        $desc,
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
