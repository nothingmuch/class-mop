#!/usr/bin/perl

use strict;
use warnings;

use Scalar::Util 'blessed', 'reftype';

use Test::More tests => 4;

BEGIN {
    use_ok('Class::MOP');
}

=pod

This checks that the initializer is used to set the initial value.

=cut

{
    package Foo;
    use metaclass;
    
    Foo->meta->add_attribute('bar' => 
        reader => 'get_bar',
        writer => 'set_bar',
        initializer => sub {
          my ($self, $value, $name, $callback) = @_;
          $callback->($value * 2);
        },
    );  
}

can_ok('Foo', 'get_bar');
can_ok('Foo', 'set_bar');    

my $foo = Foo->meta->construct_instance(bar => 10);
is(
  $foo->get_bar,
  20,
  "initial argument was doubled as expected",
);

