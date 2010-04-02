use strict;
use warnings;

use Test::More;
use Test::Exception;

use metaclass;

my %metaclass_attrs = (
    'Instance'            => 'instance_metaclass',
    'Attribute'           => 'attribute_metaclass',
    'Method'              => 'method_metaclass',
    'Method::Wrapped'     => 'wrapped_method_metaclass',
    'Method::Constructor' => 'constructor_class',
);

# meta classes
for my $suffix ('Class', keys %metaclass_attrs) {
    Class::MOP::Class->create(
        "Foo::Meta::$suffix",
        superclasses => ["Class::MOP::$suffix"]
    );
    Class::MOP::Class->create(
        "Bar::Meta::$suffix",
        superclasses => ["Class::MOP::$suffix"]
    );
    Class::MOP::Class->create(
        "FooBar::Meta::$suffix",
        superclasses => ["Foo::Meta::$suffix", "Bar::Meta::$suffix"]
    );
}

# checking...

lives_ok {
    Foo::Meta::Class->create('Foo')
} '... Foo.meta => Foo::Meta::Class is compatible';
lives_ok {
    Bar::Meta::Class->create('Bar')
} '... Bar.meta => Bar::Meta::Class is compatible';

throws_ok {
    Bar::Meta::Class->create('Foo::Foo', superclasses => ['Foo'])
} qr/compatible/, '... Foo::Foo.meta => Bar::Meta::Class is not compatible';
throws_ok {
    Foo::Meta::Class->create('Bar::Bar', superclasses => ['Bar'])
} qr/compatible/, '... Bar::Bar.meta => Foo::Meta::Class is not compatible';

lives_ok {
    FooBar::Meta::Class->create('FooBar', superclasses => ['Foo'])
} '... FooBar.meta => FooBar::Meta::Class is compatible';
lives_ok {
    FooBar::Meta::Class->create('FooBar2', superclasses => ['Bar'])
} '... FooBar2.meta => FooBar::Meta::Class is compatible';

Foo::Meta::Class->create(
    'Foo::All',
    map { $metaclass_attrs{$_} => "Foo::Meta::$_" } keys %metaclass_attrs,
);

throws_ok {
    Bar::Meta::Class->create(
        'Foo::All::Sub::Class',
        superclasses => ['Foo::All'],
        map { $metaclass_attrs{$_} => "Foo::Meta::$_" } keys %metaclass_attrs,
    )
} qr/compatible/, 'incompatible Class metaclass';
for my $suffix (keys %metaclass_attrs) {
    throws_ok {
        Foo::Meta::Class->create(
            "Foo::All::Sub::$suffix",
            superclasses => ['Foo::All'],
            (map { $metaclass_attrs{$_} => "Foo::Meta::$_" } keys %metaclass_attrs),
            $metaclass_attrs{$suffix} => "Bar::Meta::$suffix",
        )
    } qr/compatible/, "incompatible $suffix metaclass";
}

# fixing...

lives_ok {
    Class::MOP::Class->create('Foo::Foo::CMOP', superclasses => ['Foo'])
} 'metaclass fixing fixes a cmop metaclass, when the parent has a subclass';
isa_ok(Foo::Foo::CMOP->meta, 'Foo::Meta::Class');
lives_ok {
    Class::MOP::Class->create('Bar::Bar::CMOP', superclasses => ['Bar'])
} 'metaclass fixing fixes a cmop metaclass, when the parent has a subclass';
isa_ok(Bar::Bar::CMOP->meta, 'Bar::Meta::Class');

lives_ok {
    Class::MOP::Class->create(
        'Foo::All::Sub::CMOP::Class',
        superclasses => ['Foo::All'],
        map { $metaclass_attrs{$_} => "Foo::Meta::$_" } keys %metaclass_attrs,
    )
} 'metaclass fixing works with other non-default metaclasses';
isa_ok(Foo::All::Sub::CMOP::Class->meta, 'Foo::Meta::Class');

for my $suffix (keys %metaclass_attrs) {
    lives_ok {
        Foo::Meta::Class->create(
            "Foo::All::Sub::CMOP::$suffix",
            superclasses => ['Foo::All'],
            (map { $metaclass_attrs{$_} => "Foo::Meta::$_" } keys %metaclass_attrs),
            $metaclass_attrs{$suffix} => "Class::MOP::$suffix",
        )
    } "$metaclass_attrs{$suffix} fixing works with other non-default metaclasses";
    for my $suffix2 (keys %metaclass_attrs) {
        my $method = $metaclass_attrs{$suffix2};
        isa_ok("Foo::All::Sub::CMOP::$suffix"->meta->$method, "Foo::Meta::$suffix2");
    }
}

# initializing...

{
    package Foo::NoMeta;
}

Class::MOP::Class->create('Foo::NoMeta::Sub', superclasses => ['Foo::NoMeta']);
ok(!Foo::NoMeta->can('meta'), "non-cmop superclass doesn't get methods installed");
isa_ok(Class::MOP::class_of('Foo::NoMeta'), 'Class::MOP::Class');
isa_ok(Foo::NoMeta::Sub->meta, 'Class::MOP::Class');

{
    package Foo::NoMeta2;
}
Foo::Meta::Class->create('Foo::NoMeta2::Sub', superclasses => ['Foo::NoMeta2']);
ok(!Foo::NoMeta->can('meta'), "non-cmop superclass doesn't get methods installed");
isa_ok(Class::MOP::class_of('Foo::NoMeta2'), 'Class::MOP::Class');
isa_ok(Foo::NoMeta2::Sub->meta, 'Foo::Meta::Class');

Foo::Meta::Class->create('Foo::WithMeta');
{
    package Foo::WithMeta::Sub;
    use base 'Foo::WithMeta';
}
Class::MOP::Class->create(
    'Foo::WithMeta::Sub::Sub',
    superclasses => ['Foo::WithMeta::Sub']
);

isa_ok(Class::MOP::class_of('Foo::WithMeta'), 'Foo::Meta::Class');
isa_ok(Class::MOP::class_of('Foo::WithMeta::Sub'), 'Foo::Meta::Class');
isa_ok(Class::MOP::class_of('Foo::WithMeta::Sub::Sub'), 'Foo::Meta::Class');

# unsafe fixing...

{
    Class::MOP::Class->create(
        'Foo::Unsafe',
        attribute_metaclass => 'Foo::Meta::Attribute',
    );
    my $meta = Class::MOP::Class->create(
        'Foo::Unsafe::Sub',
    );
    $meta->add_attribute(foo => reader => 'foo');
    throws_ok { $meta->superclasses('Foo::Unsafe') }
              qr/compatibility.*pristine/,
              "can't switch out the attribute metaclass of a class that already has attributes";
}

done_testing;
