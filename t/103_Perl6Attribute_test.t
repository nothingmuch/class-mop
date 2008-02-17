#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
use File::Spec;

BEGIN { 
    use_ok('Class::MOP');    
    require_ok(File::Spec->catfile('examples', 'Perl6Attribute.pod'));
}

{
    package Foo;
    
    use metaclass;
    
    Foo->meta->add_attribute(Perl6Attribute->new('$.foo'));
    Foo->meta->add_attribute(Perl6Attribute->new('@.bar'));    
    Foo->meta->add_attribute(Perl6Attribute->new('%.baz'));    
    
    sub new  {
        my $class = shift;
        $class->meta->new_object(@_);
    }      
}

my $foo = Foo->new();
isa_ok($foo, 'Foo');

can_ok($foo, 'foo');
can_ok($foo, 'bar');
can_ok($foo, 'baz');

is($foo->foo, undef, '... Foo.foo == undef');

$foo->foo(42);
is($foo->foo, 42, '... Foo.foo == 42');

is_deeply($foo->bar, [], '... Foo.bar == []');
is_deeply($foo->baz, {}, '... Foo.baz == {}');
