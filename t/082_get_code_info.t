#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

BEGIN { use_ok("Class::MOP") }

use Sub::Name qw(subname);

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

