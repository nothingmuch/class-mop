use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use Class::MOP;
use lib 't/lib';

lives_ok {
    Class::MOP::load_class('TestClassLoaded::Sub');
};

TestClassLoaded->can('a_method');

lives_ok {
    Class::MOP::load_class('TestClassLoaded');
};

lives_ok {
    TestClassLoaded->a_method;
}
