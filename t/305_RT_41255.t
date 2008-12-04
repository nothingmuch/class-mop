#!/usr/bin/perl

use strict;
use Test::More tests => 10;
use Test::Exception;

use Class::MOP;

{
    package Base;
    sub m1 { 1 }
    sub m2 { 2 }
    sub m3 { 3 }
    sub m4 { 4 }
    sub m5 { 5 }

    package Derived;
    use parent -norequire => qw(Base);

    sub m1;
    sub m2 ();
    sub m3 :method;
    sub m4; m4() if 0;
    sub m5; our $m5;;
}

my $meta = Class::MOP::Class->initialize('Derived');
my %methods = map { $_ => $meta->find_method_by_name($_) } 'm1' .. 'm5';

while (my ($name, $meta_method) = each %methods) {
    is $meta_method->fully_qualified_name, "Derived::${name}";
    throws_ok { $meta_method->execute } qr/Undefined subroutine .* called at/;
}
