#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Attribute');
    use_ok('Class::MOP::Method');            
}

# make sure we are tracking metaclasses correctly

my %METAS = (
    'Class::MOP::Attribute' => Class::MOP::Attribute->meta, 
    'Class::MOP::Class'     => Class::MOP::Class->meta, 
    'Class::MOP::Method'    => Class::MOP::Method->meta  
);

is_deeply(
    { Class::MOP::Class->get_all_metaclasses },
    \%METAS,
    '... got all the metaclasses');

is_deeply(
    [ sort { $a->name cmp $b->name } Class::MOP::Class->get_all_metaclass_instances ],
    [ Class::MOP::Attribute->meta, Class::MOP::Class->meta, Class::MOP::Method->meta ],
    '... got all the metaclass instances');

is_deeply(
    [ sort Class::MOP::Class->get_all_metaclass_names ],
    [ 'Class::MOP::Attribute', 'Class::MOP::Class', 'Class::MOP::Method' ],
    '... got all the metaclass names');