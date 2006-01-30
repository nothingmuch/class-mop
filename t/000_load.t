#!/usr/bin/perl

use strict;
use warnings;

use Test::More no_plan => 1;

BEGIN {
    use_ok('Class::MOP' => '-> this-is-ignored :)');
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Attribute');
    use_ok('Class::MOP::Method');            
}