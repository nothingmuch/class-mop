#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 34;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');        
    use_ok('Class::MOP::Package');            
}

{
    package Foo;
    
    sub meta { Class::MOP::Package->initialize('Foo') }
}

ok(!defined($Foo::{foo}), '... the %foo slot has not been created yet');
ok(!Foo->meta->has_package_symbol('%foo'), '... the meta agrees');

lives_ok {
    Foo->meta->add_package_symbol('%foo' => { one => 1 });
} '... created %Foo::foo successfully';

ok(defined($Foo::{foo}), '... the %foo slot was created successfully');
ok(Foo->meta->has_package_symbol('%foo'), '... the meta agrees');

{
    no strict 'refs';
    ok(exists ${'Foo::foo'}{one}, '... our %foo was initialized correctly');
    is(${'Foo::foo'}{one}, 1, '... our %foo was initialized correctly');
}

my $foo = Foo->meta->get_package_symbol('%foo');
is_deeply({ one => 1 }, $foo, '... got the right package variable back');

$foo->{two} = 2;

{
    no strict 'refs';
    is(\%{'Foo::foo'}, Foo->meta->get_package_symbol('%foo'), '... our %foo is the same as the metas');
    
    ok(exists ${'Foo::foo'}{two}, '... our %foo was updated correctly');
    is(${'Foo::foo'}{two}, 2, '... our %foo was updated correctly');    
}

ok(!defined($Foo::{bar}), '... the @bar slot has not been created yet');

lives_ok {
    Foo->meta->add_package_symbol('@bar' => [ 1, 2, 3 ]);
} '... created @Foo::bar successfully';

ok(defined($Foo::{bar}), '... the @bar slot was created successfully');

{
    no strict 'refs';
    is(scalar @{'Foo::bar'}, 3, '... our @bar was initialized correctly');
    is(${'Foo::bar'}[1], 2, '... our @bar was initialized correctly');
}

# now without initial value

ok(!defined($Foo::{baz}), '... the %baz slot has not been created yet');

lives_ok {
    Foo->meta->add_package_symbol('%baz');
} '... created %Foo::baz successfully';

ok(defined($Foo::{baz}), '... the %baz slot was created successfully');

{
    no strict 'refs';
    ${'Foo::baz'}{one} = 1;

    ok(exists ${'Foo::baz'}{one}, '... our %baz was initialized correctly');
    is(${'Foo::baz'}{one}, 1, '... our %baz was initialized correctly');
}

ok(!defined($Foo::{bling}), '... the @bling slot has not been created yet');

lives_ok {
    Foo->meta->add_package_symbol('@bling');
} '... created @Foo::bling successfully';

ok(defined($Foo::{bling}), '... the @bling slot was created successfully');

{
    no strict 'refs';
    is(scalar @{'Foo::bling'}, 0, '... our @bling was initialized correctly');
    ${'Foo::bling'}[1] = 2;
    is(${'Foo::bling'}[1], 2, '... our @bling was assigned too correctly');
}

lives_ok {
    Foo->meta->remove_package_symbol('%foo');
} '... removed %Foo::foo successfully';

ok(Foo->meta->has_package_symbol('%foo'), '... the %foo slot was removed successfully');

# check some errors

dies_ok {
    Foo->meta->add_package_symbol('bar');
} '... no sigil for bar';

dies_ok {
    Foo->meta->remove_package_symbol('bar');
} '... no sigil for bar';

dies_ok {
    Foo->meta->get_package_symbol('bar');
} '... no sigil for bar';

dies_ok {
    Foo->meta->has_package_symbol('bar');
} '... no sigil for bar';


#dies_ok {
#    Foo->meta->get_package_symbol('@.....bar');
#} '... could not fetch variable';
