#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Attribute');
    use_ok('Class::MOP::Method');            
}