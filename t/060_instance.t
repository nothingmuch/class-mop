#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 1;
use Test::Exception;

use Scalar::Util 'reftype', 'isweak';

BEGIN {
    use_ok('Class::MOP::Instance');    
}

