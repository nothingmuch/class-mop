#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 112;
use Test::Exception;

use Scalar::Util;

BEGIN {
    use_ok('Class::MOP');
}

{
    package Foo;

    use strict;
    use warnings;
    use metaclass;

    __PACKAGE__->meta->add_attribute('bar');

    package Bar;

    use strict;
    use warnings;
    use metaclass;

    __PACKAGE__->meta->superclasses('Foo');

    __PACKAGE__->meta->add_attribute('baz');

    package Baz;

    use strict;
    use warnings;
    use metaclass;

    __PACKAGE__->meta->superclasses('Bar');

    __PACKAGE__->meta->add_attribute('bah');
}

{
    my $meta = Baz->meta;
    is($meta->name, 'Baz', '... checking the Baz metaclass');
    my @orig_keys = sort keys %$meta;

    lives_ok {$meta->make_immutable; } '... changed Baz to be immutable';
    ok(!$meta->is_mutable,              '... our class is no longer mutable');
    ok($meta->is_immutable,             '... our class is now immutable');
    ok(!$meta->make_immutable,          '... make immutable now returns nothing');
    ok($meta->get_method_map->{new},    '... inlined constructor created');
    ok($meta->has_method('new'),        '... inlined constructor created for sure');    

    lives_ok { $meta->make_mutable; }  '... changed Baz to be mutable';
    ok($meta->is_mutable,               '... our class is mutable');
    ok(!$meta->is_immutable,            '... our class is not immutable');
    ok(!$meta->make_mutable,            '... make mutable now returns nothing');
    ok(!$meta->get_method_map->{new},   '... inlined constructor removed');
    ok(!$meta->has_method('new'),        '... inlined constructor removed for sure');    

    my @new_keys = sort keys %$meta;
    is_deeply(\@orig_keys, \@new_keys, '... no straneous hashkeys');

    isa_ok($meta, 'Class::MOP::Class', '... Baz->meta isa Class::MOP::Class');

    ok( $meta->add_method('xyz', sub{'xxx'}), '... added method');
    is( Baz->xyz, 'xxx',                      '... method xyz works');

    ok(! $meta->has_method('zxy')             ,'...  we dont have the aliased method yet');    
    ok( $meta->alias_method('zxy',sub{'xxx'}),'... aliased method');
    ok(! $meta->has_method('zxy')             ,'...  the aliased method does not register (correctly)');    
    is( Baz->zxy, 'xxx',                      '... method zxy works');
    ok( $meta->remove_method('xyz'),          '... removed method');
    ok(! $meta->remove_method('zxy'),          '... removed aliased method');

    ok($meta->add_attribute('fickle', accessor => 'fickle'), '... added attribute');
    ok(Baz->can('fickle'),                '... Baz can fickle');
    ok($meta->remove_attribute('fickle'), '... removed attribute');

    my $reef = \ 'reef';
    ok($meta->add_package_symbol('$ref', $reef),      '... added package symbol');
    is($meta->get_package_symbol('$ref'), $reef,      '... values match');
    lives_ok { $meta->remove_package_symbol('$ref') } '... removed it';
    isnt($meta->get_package_symbol('$ref'), $reef,    '... values match');

    ok( my @supers = $meta->superclasses,       '... got the superclasses okay');
    ok( $meta->superclasses('Foo'),             '... set the superclasses');
    is_deeply(['Foo'], [$meta->superclasses],   '... set the superclasses okay');
    ok( $meta->superclasses( @supers ),         '... reset superclasses');
    is_deeply([@supers], [$meta->superclasses], '... reset the superclasses okay');

    ok( $meta->$_  , "... ${_} works")
      for qw(get_meta_instance       compute_all_applicable_attributes
             class_precedence_list  get_method_map );

    lives_ok {$meta->make_immutable; } '... changed Baz to be immutable again';
    ok($meta->get_method_map->{new},    '... inlined constructor recreated');
}

{
    my $meta = Baz->meta;

    lives_ok { $meta->make_immutable() } 'Changed Baz to be immutable';
    lives_ok { $meta->make_mutable() }   '... changed Baz to be mutable';
    lives_ok { $meta->make_immutable() } '... changed Baz to be immutable';

    dies_ok{ $meta->add_method('xyz', sub{'xxx'})  } '... exception thrown as expected';
    dies_ok{ $meta->alias_method('zxy',sub{'xxx'}) } '... exception thrown as expected';
    dies_ok{ $meta->remove_method('zxy')           } '... exception thrown as expected';

    dies_ok {
      $meta->add_attribute('fickle', accessor => 'fickle')
    }  '... exception thrown as expected';
    dies_ok { $meta->remove_attribute('fickle') } '... exception thrown as expected';

    my $reef = \ 'reef';
    dies_ok { $meta->add_package_symbol('$ref', $reef) } '... exception thrown as expected';
    dies_ok { $meta->remove_package_symbol('$ref')     } '... exception thrown as expected';

    ok( my @supers = $meta->superclasses,  '... got the superclasses okay');
    dies_ok { $meta->superclasses('Foo') } '... set the superclasses';

    ok( $meta->$_  , "... ${_} works")
      for qw(get_meta_instance       compute_all_applicable_attributes
             class_precedence_list  get_method_map );
}

{

    ok(Baz->meta->is_immutable,  'Superclass is immutable');
    my $meta = Baz->meta->create_anon_class(superclasses => ['Baz']);
    my @orig_keys  = sort keys %$meta;
    my @orig_meths = sort { $a->{name} cmp $b->{name} }
      $meta->compute_all_applicable_methods;
    ok($meta->is_anon_class,                  'We have an anon metaclass');
    ok($meta->is_mutable,  '... our anon class is mutable');
    ok(!$meta->is_immutable,  '... our anon class is not immutable');

    lives_ok {$meta->make_immutable(
                                    inline_accessor    => 1,
                                    inline_destructor  => 0,
                                    inline_constructor => 1,
                                   )
            } '... changed class to be immutable';
    ok(!$meta->is_mutable,                    '... our class is no longer mutable');
    ok($meta->is_immutable,                   '... our class is now immutable');
    ok(!$meta->make_immutable,                '... make immutable now returns nothing');

    lives_ok { $meta->make_mutable }  '... changed Baz to be mutable';
    ok($meta->is_mutable,             '... our class is mutable');
    ok(!$meta->is_immutable,          '... our class is not immutable');
    ok(!$meta->make_mutable,          '... make mutable now returns nothing');
    ok($meta->is_anon_class,          '... still marked as an anon class');
    my $instance = $meta->new_object;

    my @new_keys  = sort keys %$meta;
    my @new_meths = sort { $a->{name} cmp $b->{name} }
      $meta->compute_all_applicable_methods;
    is_deeply(\@orig_keys, \@new_keys, '... no straneous hashkeys');
    is_deeply(\@orig_meths, \@new_meths, '... no straneous methods');

    isa_ok($meta, 'Class::MOP::Class', '... Anon class isa Class::MOP::Class');

    ok( $meta->add_method('xyz', sub{'xxx'}), '... added method');
    is( $instance->xyz , 'xxx',               '... method xyz works');
    ok( $meta->alias_method('zxy',sub{'xxx'}),'... aliased method');
    is( $instance->zxy, 'xxx',                '... method zxy works');
    ok( $meta->remove_method('xyz'),          '... removed method');
    ok( !$meta->remove_method('zxy'),          '... removed aliased method');

    ok($meta->add_attribute('fickle', accessor => 'fickle'), '... added attribute');
    ok($instance->can('fickle'),          '... instance can fickle');
    ok($meta->remove_attribute('fickle'), '... removed attribute');

    my $reef = \ 'reef';
    ok($meta->add_package_symbol('$ref', $reef),      '... added package symbol');
    is($meta->get_package_symbol('$ref'), $reef,      '... values match');
    lives_ok { $meta->remove_package_symbol('$ref') } '... removed it';
    isnt($meta->get_package_symbol('$ref'), $reef,    '... values match');

    ok( my @supers = $meta->superclasses,       '... got the superclasses okay');
    ok( $meta->superclasses('Foo'),             '... set the superclasses');
    is_deeply(['Foo'], [$meta->superclasses],   '... set the superclasses okay');
    ok( $meta->superclasses( @supers ),         '... reset superclasses');
    is_deeply([@supers], [$meta->superclasses], '... reset the superclasses okay');

    ok( $meta->$_  , "... ${_} works")
      for qw(get_meta_instance       compute_all_applicable_attributes
             class_precedence_list  get_method_map );
};


#rerun the same tests on an anon class.. just cause we can.
{
    my $meta = Baz->meta->create_anon_class(superclasses => ['Baz']);

    lives_ok {$meta->make_immutable(
                                    inline_accessor    => 1,
                                    inline_destructor  => 0,
                                    inline_constructor => 1,
                                   )
            } '... changed class to be immutable';
    lives_ok { $meta->make_mutable() }   '... changed class to be mutable';
    lives_ok {$meta->make_immutable  } '... changed class to be immutable';

    dies_ok{ $meta->add_method('xyz', sub{'xxx'})  } '... exception thrown as expected';
    dies_ok{ $meta->alias_method('zxy',sub{'xxx'}) } '... exception thrown as expected';
    dies_ok{ $meta->remove_method('zxy')           } '... exception thrown as expected';

    dies_ok {
      $meta->add_attribute('fickle', accessor => 'fickle')
    }  '... exception thrown as expected';
    dies_ok { $meta->remove_attribute('fickle') } '... exception thrown as expected';

    my $reef = \ 'reef';
    dies_ok { $meta->add_package_symbol('$ref', $reef) } '... exception thrown as expected';
    dies_ok { $meta->remove_package_symbol('$ref')     } '... exception thrown as expected';

    ok( my @supers = $meta->superclasses,  '... got the superclasses okay');
    dies_ok { $meta->superclasses('Foo') } '... set the superclasses';

    ok( $meta->$_  , "... ${_} works")
      for qw(get_meta_instance       compute_all_applicable_attributes
             class_precedence_list  get_method_map );
}
