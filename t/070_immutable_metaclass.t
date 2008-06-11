#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 85;
use Test::Exception;

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
  my $meta = Foo->meta;

  my $transformer;
  lives_ok{ $transformer = $meta->create_immutable_transformer }
    "Created immutable transformer";
  isa_ok($transformer, 'Class::MOP::Immutable', '... transformer isa Class::MOP::Immutable');
  my $methods = $transformer->create_methods_for_immutable_metaclass;

  my $immutable_metaclass = $transformer->immutable_metaclass;
  is($transformer->metaclass, $meta,      '... transformer has correct metaclass');
  ok($immutable_metaclass->is_anon_class, '... immutable_metaclass is an anonymous class');

  #I don't understand why i need to ->meta here...
  my $obj = $immutable_metaclass->name;
  ok(!$obj->is_mutable,     '... immutable_metaclass is not mutable');
  ok($obj->is_immutable,    '... immutable_metaclass is immutable');
  ok(!$obj->make_immutable, '... immutable_metaclass make_mutable is noop');
  is($obj->meta, $immutable_metaclass, '... immutable_metaclass meta hack works');

  is_deeply(
            [ $immutable_metaclass->superclasses ],
            [ Scalar::Util::blessed($meta) ],
            '... immutable_metaclass superclasses are correct'
           );
  ok($immutable_metaclass->has_method('get_mutable_metaclass_name'));

}

{
    my $meta = Foo->meta;
    is($meta->name, 'Foo', '... checking the Foo metaclass');

    ok($meta->is_mutable, '... our class is mutable');
    ok(!$meta->is_immutable, '... our class is not immutable');

    my $transformer = $meta->get_immutable_transformer;

    lives_ok {
        $meta->make_immutable();
    } '... changed Foo to be immutable';

    is($transformer, $meta->get_immutable_transformer, '... immutable transformer cache works');
    ok(!$meta->make_immutable, '... make immutable now returns nothing');

    ok(!$meta->is_mutable, '... our class is no longer mutable');
    ok($meta->is_immutable, '... our class is now immutable');

    isa_ok($meta, 'Class::MOP::Class');

    dies_ok { $meta->add_method()    } '... exception thrown as expected';
    dies_ok { $meta->alias_method()  } '... exception thrown as expected';
    dies_ok { $meta->remove_method() } '... exception thrown as expected';

    dies_ok { $meta->add_attribute()    } '... exception thrown as expected';
    dies_ok { $meta->remove_attribute() } '... exception thrown as expected';

    dies_ok { $meta->add_package_symbol()    } '... exception thrown as expected';
    dies_ok { $meta->remove_package_symbol() } '... exception thrown as expected';

    lives_ok { $meta->identifier() } '... no exception for get_package_symbol special case';

    my @supers;
    lives_ok {
        @supers = $meta->superclasses;
    } '... got the superclasses okay';

    dies_ok { $meta->superclasses([ 'UNIVERSAL' ]) } '... but could not set the superclasses okay';

    my $meta_instance;
    lives_ok {
        $meta_instance = $meta->get_meta_instance;
    } '... got the meta instance okay';
    isa_ok($meta_instance, 'Class::MOP::Instance');
    is($meta_instance, $meta->get_meta_instance, '... and we know it is cached');

    my @cpl;
    lives_ok {
        @cpl = $meta->class_precedence_list;
    } '... got the class precedence list okay';
    is_deeply(
    \@cpl,
    [ 'Foo' ],
    '... we just have ourselves in the class precedence list');

    my @attributes;
    lives_ok {
        @attributes = $meta->compute_all_applicable_attributes;
    } '... got the attribute list okay';
    is_deeply(
    \@attributes,
    [ $meta->get_attribute('bar') ],
    '... got the right list of attributes');
}

{
    my $meta = Bar->meta;
    is($meta->name, 'Bar', '... checking the Bar metaclass');

    ok($meta->is_mutable, '... our class is mutable');
    ok(!$meta->is_immutable, '... our class is not immutable');

    lives_ok {
        $meta->make_immutable();
    } '... changed Bar to be immutable';

    ok(!$meta->make_immutable, '... make immutable now returns nothing');

    ok(!$meta->is_mutable, '... our class is no longer mutable');
    ok($meta->is_immutable, '... our class is now immutable');

    isa_ok($meta, 'Class::MOP::Class');

    dies_ok { $meta->add_method()    } '... exception thrown as expected';
    dies_ok { $meta->alias_method()  } '... exception thrown as expected';
    dies_ok { $meta->remove_method() } '... exception thrown as expected';

    dies_ok { $meta->add_attribute()    } '... exception thrown as expected';
    dies_ok { $meta->remove_attribute() } '... exception thrown as expected';

    dies_ok { $meta->add_package_symbol()    } '... exception thrown as expected';
    dies_ok { $meta->remove_package_symbol() } '... exception thrown as expected';

    my @supers;
    lives_ok {
        @supers = $meta->superclasses;
    } '... got the superclasses okay';

    dies_ok { $meta->superclasses([ 'UNIVERSAL' ]) } '... but could not set the superclasses okay';

    my $meta_instance;
    lives_ok {
        $meta_instance = $meta->get_meta_instance;
    } '... got the meta instance okay';
    isa_ok($meta_instance, 'Class::MOP::Instance');
    is($meta_instance, $meta->get_meta_instance, '... and we know it is cached');

    my @cpl;
    lives_ok {
        @cpl = $meta->class_precedence_list;
    } '... got the class precedence list okay';
    is_deeply(
    \@cpl,
    [ 'Bar', 'Foo'],
    '... we just have ourselves in the class precedence list');

    my @attributes;
    lives_ok {
        @attributes = $meta->compute_all_applicable_attributes;
    } '... got the attribute list okay';
    is_deeply(
    [ sort { $a->name cmp $b->name } @attributes ],
    [ Foo->meta->get_attribute('bar'), $meta->get_attribute('baz') ],
    '... got the right list of attributes');
}

{
    my $meta = Baz->meta;
    is($meta->name, 'Baz', '... checking the Baz metaclass');

    ok($meta->is_mutable, '... our class is mutable');
    ok(!$meta->is_immutable, '... our class is not immutable');

    lives_ok {
        $meta->make_immutable();
    } '... changed Baz to be immutable';

    ok(!$meta->make_immutable, '... make immutable now returns nothing');

    ok(!$meta->is_mutable, '... our class is no longer mutable');
    ok($meta->is_immutable, '... our class is now immutable');

    isa_ok($meta, 'Class::MOP::Class');

    dies_ok { $meta->add_method()    } '... exception thrown as expected';
    dies_ok { $meta->alias_method()  } '... exception thrown as expected';
    dies_ok { $meta->remove_method() } '... exception thrown as expected';

    dies_ok { $meta->add_attribute()    } '... exception thrown as expected';
    dies_ok { $meta->remove_attribute() } '... exception thrown as expected';

    dies_ok { $meta->add_package_symbol()    } '... exception thrown as expected';
    dies_ok { $meta->remove_package_symbol() } '... exception thrown as expected';

    my @supers;
    lives_ok {
        @supers = $meta->superclasses;
    } '... got the superclasses okay';

    dies_ok { $meta->superclasses([ 'UNIVERSAL' ]) } '... but could not set the superclasses okay';

    my $meta_instance;
    lives_ok {
        $meta_instance = $meta->get_meta_instance;
    } '... got the meta instance okay';
    isa_ok($meta_instance, 'Class::MOP::Instance');
    is($meta_instance, $meta->get_meta_instance, '... and we know it is cached');

    my @cpl;
    lives_ok {
        @cpl = $meta->class_precedence_list;
    } '... got the class precedence list okay';
    is_deeply(
    \@cpl,
    [ 'Baz', 'Bar', 'Foo'],
    '... we just have ourselves in the class precedence list');

    my @attributes;
    lives_ok {
        @attributes = $meta->compute_all_applicable_attributes;
    } '... got the attribute list okay';
    is_deeply(
    [ sort { $a->name cmp $b->name } @attributes ],
    [ $meta->get_attribute('bah'), Foo->meta->get_attribute('bar'), Bar->meta->get_attribute('baz') ],
    '... got the right list of attributes');
}


