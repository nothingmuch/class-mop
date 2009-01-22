use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More;
use Class::MOP ();

plan 'skip_all' => 'This test is only meaningful for an XS-enabled CMOP with Perl < 5.10'
    if Class::MOP::IS_RUNNING_ON_5_10() || ! Class::MOP::USING_XS();


plan tests => 1;

# With pre-5.10 Perl, just defining this sub appears to shit in
# TestClassLoaded's symbol tables (see the SCALAR package symbol you
# end up with).  This confuses the XS is_class_loaded method, which
# looks for _any_ symbol, not just code symbols of VERSION/AUTHORITY
# etc.

sub whatever {
    TestClassLoaded::this_method_does_not_even_exist();
}

Class::MOP::load_class('TestClassLoaded');

TODO: {
    local $TODO = 'The XS is_class_loaded is confused by the bogus method defined in whatever()';
    ok(
        TestClassLoaded->can('a_method'),
        'TestClassLoader::a_method is defined'
    );
}

