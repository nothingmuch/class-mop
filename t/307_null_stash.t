#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 1;

use Class::MOP;
my $map = Class::MOP::Class->initialize('Non::Existent::Package')->get_method_map;
pass("empty stashes don't segfault");
