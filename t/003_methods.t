#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 65;
use Test::Exception;

use Scalar::Util qw/reftype/;
use Sub::Name ();

BEGIN {
    use_ok('Class::MOP');   
    use_ok('Class::MOP::Class');        
}

{   # This package tries to test &has_method 
    # as exhaustively as possible. More corner
    # cases are welcome :)
    package Foo;
    
    # import a sub
    use Scalar::Util 'blessed'; 
    
    sub pie;
    sub cake ();

    use constant FOO_CONSTANT => 'Foo-CONSTANT';
    
    # define a sub in package
    sub bar { 'Foo::bar' } 
    *baz = \&bar;
    
    # create something with the typeglob inside the package
    *baaz = sub { 'Foo::baaz' };    

    { # method named with Sub::Name inside the package scope
        no strict 'refs';
        *{'Foo::floob'} = Sub::Name::subname 'floob' => sub { '!floob!' }; 
    }

    # We hateses the "used only once" warnings
    { 
        my $temp1 = \&Foo::baz;
        my $temp2 = \&Foo::baaz;    
    }
    
    package OinkyBoinky;
    our @ISA = "Foo";
    
    sub elk { 'OinkyBoinky::elk' }

    package main;
    
    sub Foo::blah { $_[0]->Foo::baz() }
    
    {
        no strict 'refs';
        *{'Foo::bling'} = sub { '$$Bling$$' };
        *{'Foo::bang'} = Sub::Name::subname 'Foo::bang' => sub { '!BANG!' }; 
        *{'Foo::boom'} = Sub::Name::subname 'boom' => sub { '!BOOM!' };     
        
        eval "package Foo; sub evaled_foo { 'Foo::evaled_foo' }";           
    }
}

my $Foo = Class::MOP::Class->initialize('Foo');

ok(!$Foo->has_method('pie'), '... got the method stub pie');
ok(!$Foo->has_method('cake'), '... got the constant method stub cake');

my $foo = sub { 'Foo::foo' };

ok(!UNIVERSAL::isa($foo, 'Class::MOP::Method'), '... our method is not yet blessed');

lives_ok {
    $Foo->add_method('foo' => $foo);
} '... we added the method successfully';

my $foo_method = $Foo->get_method('foo');

isa_ok($foo_method, 'Class::MOP::Method');

is($foo_method->name, 'foo', '... got the right name for the method');
is($foo_method->package_name, 'Foo', '... got the right package name for the method');

ok($Foo->has_method('foo'), '... Foo->has_method(foo) (defined with Sub::Name)');

is($Foo->get_method('foo')->body, $foo, '... Foo->get_method(foo) == \&foo');
is(Foo->foo(), 'Foo::foo', '... Foo->foo() returns "Foo::foo"');

# now check all our other items ...

ok($Foo->has_method('FOO_CONSTANT'), '... not Foo->has_method(FOO_CONSTANT) (defined w/ use constant)');
ok(!$Foo->has_method('bling'), '... not Foo->has_method(bling) (defined in main:: using symbol tables (no Sub::Name))');

ok($Foo->has_method('bar'), '... Foo->has_method(bar) (defined in Foo)');
ok($Foo->has_method('baz'), '... Foo->has_method(baz) (typeglob aliased within Foo)');
ok($Foo->has_method('baaz'), '... Foo->has_method(baaz) (typeglob aliased within Foo)');
ok($Foo->has_method('floob'), '... Foo->has_method(floob) (defined in Foo:: using symbol tables and Sub::Name w/out package name)');
ok($Foo->has_method('blah'), '... Foo->has_method(blah) (defined in main:: using fully qualified package name)');
ok($Foo->has_method('bang'), '... Foo->has_method(bang) (defined in main:: using symbol tables and Sub::Name)');
ok($Foo->has_method('evaled_foo'), '... Foo->has_method(evaled_foo) (evaled in main::)');

my $OinkyBoinky = Class::MOP::Class->initialize('OinkyBoinky');

ok($OinkyBoinky->has_method('elk'), "the method 'elk' is defined in OinkyBoinky");

ok(!$OinkyBoinky->has_method('bar'), "the method 'bar' is not defined in OinkyBoinky");

ok(my $bar = $OinkyBoinky->find_method_by_name('bar'), "but if you look in the inheritence chain then 'bar' does exist");

is( reftype($bar->body), "CODE", "the returned value is a code ref" );


# calling get_method blessed them all
for my $method_name (qw/baaz
                        bar
                    	baz
                    	floob
                    	blah
                    	bang
                    	evaled_foo
                    	FOO_CONSTANT/) {
    isa_ok($Foo->get_method($method_name), 'Class::MOP::Method');
    {
        no strict 'refs';
        is($Foo->get_method($method_name)->body, \&{'Foo::' . $method_name}, '... body matches CODE ref in package for ' . $method_name);
    }
}

for my $method_name (qw/
                    bling
                    /) {
    is(ref($Foo->get_package_symbol('&' . $method_name)), 'CODE', '... got the __ANON__ methods');
    {
        no strict 'refs';
        is($Foo->get_package_symbol('&' . $method_name), \&{'Foo::' . $method_name}, '... symbol matches CODE ref in package for ' . $method_name);
    }
}

{
    package Foo::Aliasing;
    use metaclass;
    sub alias_me { '...' }
}

$Foo->alias_method('alias_me' => Foo::Aliasing->meta->get_method('alias_me'));

ok(!$Foo->has_method('alias_me'), '... !Foo->has_method(alias_me) (aliased from Foo::Aliasing)');
ok(defined &Foo::alias_me, '... Foo does have a symbol table slow for alias_me though');

ok(!$Foo->has_method('blessed'), '... !Foo->has_method(blessed) (imported into Foo)');
ok(!$Foo->has_method('boom'), '... !Foo->has_method(boom) (defined in main:: using symbol tables and Sub::Name w/out package name)');

ok(!$Foo->has_method('not_a_real_method'), '... !Foo->has_method(not_a_real_method) (does not exist)');
is($Foo->get_method('not_a_real_method'), undef, '... Foo->get_method(not_a_real_method) == undef');

is_deeply(
    [ sort $Foo->get_method_list ],
    [ qw(FOO_CONSTANT baaz bang bar baz blah evaled_foo floob foo) ],
    '... got the right method list for Foo');

is_deeply(
    [ sort { $a->{name} cmp $b->{name} } $Foo->compute_all_applicable_methods() ],
    [
        map {
            {
            name  => $_,
            class => 'Foo',
            code  => $Foo->get_method($_)
            }
        } qw(
            FOO_CONSTANT
            baaz            
            bang 
            bar 
            baz 
            blah 
            evaled_foo 
            floob 
            foo
        )
    ],
    '... got the right list of applicable methods for Foo');

is($Foo->remove_method('foo')->body, $foo, '... removed the foo method');
ok(!$Foo->has_method('foo'), '... !Foo->has_method(foo) we just removed it');
dies_ok { Foo->foo } '... cannot call Foo->foo because it is not there';

is_deeply(
    [ sort $Foo->get_method_list ],
    [ qw(FOO_CONSTANT baaz bang bar baz blah evaled_foo floob) ],
    '... got the right method list for Foo');


# ... test our class creator 

my $Bar = Class::MOP::Class->create(
            'Bar' => (
                superclasses => [ 'Foo' ],
                methods => {
                    foo => sub { 'Bar::foo' },
                    bar => sub { 'Bar::bar' },                    
                }
            ));
isa_ok($Bar, 'Class::MOP::Class');

ok($Bar->has_method('foo'), '... Bar->has_method(foo)');
ok($Bar->has_method('bar'), '... Bar->has_method(bar)');

is(Bar->foo, 'Bar::foo', '... Bar->foo == Bar::foo');
is(Bar->bar, 'Bar::bar', '... Bar->bar == Bar::bar');

lives_ok {
    $Bar->add_method('foo' => sub { 'Bar::foo v2' });
} '... overwriting a method is fine';

ok($Bar->has_method('foo'), '... Bar-> (still) has_method(foo)');
is(Bar->foo, 'Bar::foo v2', '... Bar->foo == "Bar::foo v2"');

is_deeply(
    [ sort $Bar->get_method_list ],
    [ qw(bar foo meta) ],
    '... got the right method list for Bar');  
    
is_deeply(
    [ sort { $a->{name} cmp $b->{name} } $Bar->compute_all_applicable_methods() ],
    [
        {
            name  => 'FOO_CONSTANT',
            class => 'Foo',
            code  => $Foo->get_method('FOO_CONSTANT')
        },    
        {
            name  => 'baaz',
            class => 'Foo',
            code  => $Foo->get_method('baaz')
        },
        {
            name  => 'bang',
            class => 'Foo',
            code  => $Foo->get_method('bang')
        },
        {
            name  => 'bar',
            class => 'Bar',
            code  => $Bar->get_method('bar') 
        },
        (map {
            {
                name  => $_,
                class => 'Foo',
                code  => $Foo->get_method($_)
            }
        } qw(        
            baz 
            blah 
            evaled_foo 
            floob 
        )),
        {
            name  => 'foo',
            class => 'Bar',
            code  => $Bar->get_method('foo')
        },        
        {
            name  => 'meta',
            class => 'Bar',
            code  => $Bar->get_method('meta')
        }        
    ],
    '... got the right list of applicable methods for Bar');


