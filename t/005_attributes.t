use strict;
use warnings;

use Test::More tests => 90;
use Test::Exception;

use Class::MOP;

my $FOO_ATTR = Class::MOP::Attribute->new('$foo');
my $BAR_ATTR = Class::MOP::Attribute->new('$bar' => (
    accessor => 'bar'
));
my $BAZ_ATTR = Class::MOP::Attribute->new('$baz' => (
    reader => 'get_baz',
    writer => 'set_baz',
));

my $BAR_ATTR_2 = Class::MOP::Attribute->new('$bar');

my $FOO_ATTR_2 = Class::MOP::Attribute->new('$foo' => (
    accessor => 'foo',
    builder => 'build_foo'
));

is($FOO_ATTR->name, '$foo', '... got the attributes name correctly');
is($BAR_ATTR->name, '$bar', '... got the attributes name correctly');
is($BAZ_ATTR->name, '$baz', '... got the attributes name correctly');

{
    package Foo;
    use metaclass;

    my $meta = Foo->meta;
    ::lives_ok {
        $meta->add_attribute($FOO_ATTR);
    } '... we added an attribute to Foo successfully';
    ::ok($meta->has_attribute('$foo'), '... Foo has $foo attribute');
    ::is($meta->get_attribute('$foo'), $FOO_ATTR, '... got the right attribute back for Foo');

    ::ok(!$meta->has_method('foo'), '... no accessor created');

    ::lives_ok {
        $meta->add_attribute($BAR_ATTR_2);
    } '... we added an attribute to Foo successfully';
    ::ok($meta->has_attribute('$bar'), '... Foo has $bar attribute');
    ::is($meta->get_attribute('$bar'), $BAR_ATTR_2, '... got the right attribute back for Foo');

    ::ok(!$meta->has_method('bar'), '... no accessor created');
}
{
    package Bar;
    our @ISA = ('Foo');

    my $meta = Bar->meta;
    ::lives_ok {
        $meta->add_attribute($BAR_ATTR);
    } '... we added an attribute to Bar successfully';
    ::ok($meta->has_attribute('$bar'), '... Bar has $bar attribute');
    ::is($meta->get_attribute('$bar'), $BAR_ATTR, '... got the right attribute back for Bar');

    my $attr = $meta->get_attribute('$bar');
    ::is($attr->get_read_method,  'bar', '... got the right read method for Bar');
    ::is($attr->get_write_method, 'bar', '... got the right write method for Bar');

    ::ok($meta->has_method('bar'), '... an accessor has been created');
    ::isa_ok($meta->get_method('bar'), 'Class::MOP::Method::Accessor');
}
{
    package Baz;
    our @ISA = ('Bar');

    my $meta = Baz->meta;
    ::lives_ok {
        $meta->add_attribute($BAZ_ATTR);
    } '... we added an attribute to Baz successfully';
    ::ok($meta->has_attribute('$baz'), '... Baz has $baz attribute');
    ::is($meta->get_attribute('$baz'), $BAZ_ATTR, '... got the right attribute back for Baz');

    my $attr = $meta->get_attribute('$baz');
    ::is($attr->get_read_method,  'get_baz', '... got the right read method for Baz');
    ::is($attr->get_write_method, 'set_baz', '... got the right write method for Baz');

    ::ok($meta->has_method('get_baz'), '... a reader has been created');
    ::ok($meta->has_method('set_baz'), '... a writer has been created');

    ::isa_ok($meta->get_method('get_baz'), 'Class::MOP::Method::Reader');
    ::isa_ok($meta->get_method('set_baz'), 'Class::MOP::Method::Accessor');
}

{
    package Foo2;
    use metaclass;

    my $meta = Foo2->meta;
    $meta->add_attribute(
        Class::MOP::Attribute->new( '$foo2' => ( reader => 'foo2' ) ) );

    ::ok( $meta->has_method('foo2'), '... a reader has been created' );

    my $attr = $meta->get_attribute('$foo2');
    ::is( $attr->get_read_method, 'foo2',
        '... got the right read method for Foo2' );
    ::is( $attr->get_write_method, undef,
        '... got undef for the writer with a read-only attribute in Foo2' );
}

{
    my $meta = Baz->meta;
    isa_ok($meta, 'Class::MOP::Class');

    is($meta->find_attribute_by_name('$bar'), $BAR_ATTR, '... got the right attribute for "bar"');
    is($meta->find_attribute_by_name('$baz'), $BAZ_ATTR, '... got the right attribute for "baz"');
    is($meta->find_attribute_by_name('$foo'), $FOO_ATTR, '... got the right attribute for "foo"');

    is_deeply(
        [ sort { $a->name cmp $b->name } $meta->get_all_attributes() ],
        [
            $BAR_ATTR,
            $BAZ_ATTR,
            $FOO_ATTR,
        ],
        '... got the right list of applicable attributes for Baz');

    is_deeply(
        [ map { $_->associated_class } sort { $a->name cmp $b->name } $meta->get_all_attributes() ],
        [ Bar->meta, Baz->meta, Foo->meta ],
        '... got the right list of associated classes from the applicable attributes for Baz');

    my $attr;
    lives_ok {
        $attr = $meta->remove_attribute('$baz');
    } '... removed the $baz attribute successfully';
    is($attr, $BAZ_ATTR, '... got the right attribute back for Baz');

    ok(!$meta->has_attribute('$baz'), '... Baz no longer has $baz attribute');
    is($meta->get_attribute('$baz'), undef, '... Baz no longer has $baz attribute');

    ok(!$meta->has_method('get_baz'), '... a reader has been removed');
    ok(!$meta->has_method('set_baz'), '... a writer has been removed');

    is_deeply(
        [ sort { $a->name cmp $b->name } $meta->get_all_attributes() ],
        [
            $BAR_ATTR,
            $FOO_ATTR,
        ],
        '... got the right list of applicable attributes for Baz');

    is_deeply(
        [ map { $_->associated_class } sort { $a->name cmp $b->name } $meta->get_all_attributes() ],
        [ Bar->meta, Foo->meta ],
        '... got the right list of associated classes from the applicable attributes for Baz');

     {
         my $attr;
         lives_ok {
             $attr = Bar->meta->remove_attribute('$bar');
         } '... removed the $bar attribute successfully';
         is($attr, $BAR_ATTR, '... got the right attribute back for Bar');

         ok(!Bar->meta->has_attribute('$bar'), '... Bar no longer has $bar attribute');

         ok(!Bar->meta->has_method('bar'), '... a accessor has been removed');
     }

     is_deeply(
         [ sort { $a->name cmp $b->name } $meta->get_all_attributes() ],
         [
             $BAR_ATTR_2,
             $FOO_ATTR,
         ],
         '... got the right list of applicable attributes for Baz');

     is_deeply(
         [ map { $_->associated_class } sort { $a->name cmp $b->name } $meta->get_all_attributes() ],
         [ Foo->meta, Foo->meta ],
         '... got the right list of associated classes from the applicable attributes for Baz');

    # remove attribute which is not there
    my $val;
    lives_ok {
        $val = $meta->remove_attribute('$blammo');
    } '... attempted to remove the non-existent $blammo attribute';
    is($val, undef, '... got the right value back (undef)');

}

{
    package Buzz;
    use metaclass;
    use Scalar::Util qw/blessed/;

    my $meta = Buzz->meta;
    ::lives_ok {
        $meta->add_attribute($FOO_ATTR_2);
    } '... we added an attribute to Buzz successfully';

    ::lives_ok {
        $meta->add_attribute(
            Class::MOP::Attribute->new(
                 '$bar' => (
                            accessor  => 'bar',
                            predicate => 'has_bar',
                            clearer   => 'clear_bar',
                           )
                )
        );
    } '... we added an attribute to Buzz successfully';

    ::lives_ok {
        $meta->add_attribute(
            Class::MOP::Attribute->new(
                 '$bah' => (
                            accessor  => 'bah',
                            predicate => 'has_bah',
                            clearer   => 'clear_bah',
                            default   => 'BAH',
                           )
                )
        );
    } '... we added an attribute to Buzz successfully';

    ::lives_ok {
        $meta->add_method(build_foo => sub{ blessed shift; });
    } '... we added a method to Buzz successfully';
}



for(1 .. 2){
  my $buzz;
  ::lives_ok { $buzz = Buzz->meta->new_object } '...Buzz instantiated successfully';
  ::is($buzz->foo, 'Buzz', '...foo builder works as expected');
  ::ok(!$buzz->has_bar, '...bar is not set');
  ::is($buzz->bar, undef, '...bar returns undef');
  ::ok(!$buzz->has_bar, '...bar was not autovivified');

  $buzz->bar(undef);
  ::ok($buzz->has_bar, '...bar is set');
  ::is($buzz->bar, undef, '...bar is undef');
  $buzz->clear_bar;
  ::ok(!$buzz->has_bar, '...bar is no longerset');

  my $buzz2;
  ::lives_ok { $buzz2 = Buzz->meta->new_object('$bar' => undef) } '...Buzz instantiated successfully';
  ::ok($buzz2->has_bar, '...bar is set');
  ::is($buzz2->bar, undef, '...bar is undef');

  my $buzz3;
  ::lives_ok { $buzz3 = Buzz->meta->new_object } '...Buzz instantiated successfully';
  ::ok($buzz3->has_bah, '...bah is set');
  ::is($buzz3->bah, 'BAH', '...bah returns "BAH" ');

  my $buzz4;
  ::lives_ok { $buzz4 = Buzz->meta->new_object('$bah' => undef) } '...Buzz instantiated successfully';
  ::ok($buzz4->has_bah, '...bah is set');
  ::is($buzz4->bah, undef, '...bah is undef');

  Buzz->meta->make_immutable();
}
