use strict;
use warnings;

use Scalar::Util 'reftype', 'blessed';

use Test::More tests => 6;
use Test::Exception;

use Class::MOP;
use Class::MOP::Attribute;
use Class::MOP::Method;


{
    package Foo;
    use metaclass;

    Foo->meta->add_attribute(
        bar => (
            lazy => 1,
            default => 'haha',
        )
    );
    Foo->meta->add_attribute(
        baz => (
            lazy => 1,
            builder => 'buildit',
        )
    );

    sub buildit { 'built' }
}

{
    use Devel::Sub::Which qw(:universal);

    my $obj = Foo->meta->new_object();
    my $attrs = $obj->meta->get_attribute_map();

    my $bar_attr = $attrs->{bar};
    ok(!$bar_attr->has_value($obj), '... $attr has not had value set');
    is($bar_attr->get_value($obj), 'haha', '... $attr value is correct');
    ok($bar_attr->has_value($obj), '... $attr has had value set');

    my $baz_attr = $attrs->{baz};
    ok(!$baz_attr->has_value($obj), '... $attr has not had value set');
    is($baz_attr->get_value($obj), 'built', '... $attr value is correct');
    ok($baz_attr->has_value($obj), '... $attr has had value set');
}




