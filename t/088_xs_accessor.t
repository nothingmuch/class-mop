use strict;
use warnings;
use Test::More tests => 5;
use Class::MOP;

use B qw(svref_2object);

sub method_type{
    my($class, $method) = @_;
    return svref_2object($class->can($method))->XSUB    ? 'XS'
         : $class->meta->get_method($method)->is_inline ? 'Inline'
                                                        : 'Basic';
}


{
    package Foo;
    use metaclass;
    __PACKAGE__->meta->add_attribute('r'  => (reader    => 'r'));
    __PACKAGE__->meta->add_attribute('w'  => (writer    => 'w'));
    __PACKAGE__->meta->add_attribute('a'  => (accessor  => 'a'));
    __PACKAGE__->meta->add_attribute('c'  => (clearer   => 'c'));
    __PACKAGE__->meta->add_attribute('p'  => (predicate => 'p'));
}

is method_type('Foo', 'r'), 'XS', 'reader is XS';
is method_type('Foo', 'w'), 'XS', 'writer is XS';
is method_type('Foo', 'a'), 'XS', 'accessor is XS';
is method_type('Foo', 'c'), 'XS', 'clearer is XS';
is method_type('Foo', 'p'), 'XS', 'predicate is XS';


