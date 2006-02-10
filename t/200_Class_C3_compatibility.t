#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

=pod

This tests that Class::MOP works correctly 
with Class::C3 and it's somewhat insane 
approach to method resolution.

=cut

BEGIN {
    eval "use Class::C3";
    plan skip_all => "Class::C3 required for this test" if $@;
    plan tests => 7;    
}

{
    package Diamond_A;
    Class::C3->import; 
    use metaclass; # everyone will just inherit this now :)
    
    sub hello { 'Diamond_A::hello' }
}
{
    package Diamond_B;
    use base 'Diamond_A';
    Class::C3->import; 
}
{
    package Diamond_C;
    Class::C3->import; 
    use base 'Diamond_A';     
    
    sub hello { 'Diamond_C::hello' }
}
{
    package Diamond_D;
    use base ('Diamond_B', 'Diamond_C');
    Class::C3->import; 
}

# we have to manually initialize 
# Class::C3 since we potentially 
# skip this test if it is not present
Class::C3::initialize();

is_deeply(
    [ Class::C3::calculateMRO('Diamond_D') ],
    [ qw(Diamond_D Diamond_B Diamond_C Diamond_A) ],
    '... got the right MRO for Diamond_D');

ok(Diamond_A->meta->has_method('hello'), '... A has a method hello');
ok(!Diamond_B->meta->has_method('hello'), '... B does not have a method hello');
ok(defined &Diamond_B::hello, '... B does have an alias to the method hello');    

ok(Diamond_C->meta->has_method('hello'), '... C has a method hello');
ok(!Diamond_D->meta->has_method('hello'), '... D does not have a method hello');
ok(defined &Diamond_D::hello, '... D does have an alias to the method hello');    
