use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More;
use Class::MOP ();

plan tests => 1;

# There was a bug that manifest on Perl < 5.10 when running under
# XS. The mere mention of TestClassLoaded below broke the
# is_class_loaded check.

sub whatever {
    TestClassLoaded::this_method_does_not_even_exist();
}

Class::MOP::load_class('TestClassLoaded');

ok( TestClassLoaded->can('a_method'),
    'TestClassLoader::a_method is defined' );


