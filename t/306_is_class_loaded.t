use strict;
use warnings;
use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More tests => 1;
use Class::MOP ();

# Just defining this sub appears to shit in TestClassLoaded's symbol
# tables (see the SCALAR package symbol you end up with).
# This confuses the XS is_class_loaded method, which looks for _any_
# symbol, not just code symbols of VERSION/AUTHORITY etc.

sub fnar {
    TestClassLoaded::this_method_does_not_even_exist()
}

Class::MOP::load_class('TestClassLoaded');

TODO: {
    local $TODO = 'Borked';
    ok(TestClassLoaded->can('a_method'), 
        'TestClassLoader::a_method is defined');
}

