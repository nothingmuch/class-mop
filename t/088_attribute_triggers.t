#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 40;
use Test::Exception;

my $bar_set;
my $baz_set;
{
    package Foo;
    use metaclass;

    sub new{
        my($class, @args) = @_;
        return $class->meta->new_object(@args);
    }

   ::lives_ok{
        __PACKAGE__->meta->add_attribute('bar' =>
                      reader    => 'get_bar',
                      writer    => 'set_bar',
                      predicate => 'has_bar',
                      clearer   => 'clear_bar',

                      trigger => sub {
                          my ($self, $bar) = @_;
                          $bar_set = $bar;
        });
    };

   ::lives_ok{
       __PACKAGE__->meta->add_attribute('baz' =>
                     accessor  => 'baz',
                     predicate => 'has_baz',
                     clearer   => 'clear_baz',
                     trigger   => '_baz_set',
      );
   };

   sub _baz_set {
       my ($self, $baz) = @_;
       $baz_set = $baz;
   }
}

TEST:{
    my $foo = Foo->new(bar => '*bar*', baz => '*baz*');

    isa_ok $foo, 'Foo';

    is $foo->get_bar, '*bar*';
    is $foo->baz, '*baz*';

    is $bar_set, '*bar*', 'trigger (CODE ref) on initialization';
    is $baz_set, '*baz*', 'trigger (method name) on initialization';

    $foo->set_bar('_bar_');
    $foo->baz('_baz_');

    is $foo->get_bar, '_bar_';
    is $foo->baz, '_baz_';

    is $bar_set, '_bar_', 'trigger (CODE ref) on the writer';
    is $baz_set, '_baz_', 'trigger (method name) on the writer';

    ok $foo->has_bar();
    ok $foo->has_baz();

    is $bar_set, '_bar_', 'trigger (CODE ref) not called on the predicate';
    is $baz_set, '_baz_', 'trigger (method name) not called on the predicate';

    $foo->clear_bar();
    $foo->clear_baz();

    is $bar_set, undef, 'trigger (CODE ref) called on the clearer';
    is $baz_set, undef, 'trigger (method name) called on the clearer';

    ok !$foo->has_bar();
    ok !$foo->has_baz();


    if($foo->meta->is_mutable){
        ok $foo->meta->make_immutable(replace_constructor => 1), 'make_immutable()';
        redo TEST;
    }
}

# edge cases
{
    package XXX;
    use metaclass;

    ::throws_ok{
        __PACKAGE__->meta->add_attribute(fail =>
            trigger => {},
        );
    } qr/trigger/;

    ::throws_ok{
        __PACKAGE__->meta->add_attribute(fail =>
            trigger => [],
        );
    } qr/trigger/;


    ::throws_ok{
        __PACKAGE__->meta->add_attribute(fail =>
            trigger => undef,
        );
    } qr/trigger/;
}

