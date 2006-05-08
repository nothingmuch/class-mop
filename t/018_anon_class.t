#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
}

my $anon_class_id;
{
    my $anon_class = Class::MOP::Class->create_anon_class();
    isa_ok($anon_class, 'Class::MOP::Class');
    
    ($anon_class_id) = ($anon_class->name =~ /Class::MOP::Class::__ANON__::SERIAL::(\d+)/);
    
    ok(exists $main::Class::MOP::Class::__ANON__::SERIAL::{$anon_class_id . '::'}, '... the package exists');
    
    like($anon_class->name, qr/Class::MOP::Class::__ANON__::SERIAL::[0-9]+/, '... got an anon class package name');

    lives_ok {
        $anon_class->add_method('foo' => sub { "__ANON__::foo" });
    } '... added a method to my anon-class';

    my $instance = $anon_class->new_object();
    isa_ok($instance, $anon_class->name);

    is($instance->foo, '__ANON__::foo', '... got the right return value of our foo method');
}

ok(!exists $main::Class::MOP::Class::__ANON__::SERIAL::{$anon_class_id . '::'}, '... the package no longer exists');

# NOTE:
# I bumped this test up to 100_000 instances, and 
# still got not conflicts. If your application needs
# more than that, your probably mst

my %conflicts;
foreach my $i (1 .. 1000) {
    $conflicts{ Class::MOP::Class->create_anon_class()->name } = undef;
}
is(scalar(keys %conflicts), 1000, '... got as many classes as I would expect');

