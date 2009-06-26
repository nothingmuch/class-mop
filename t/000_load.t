use strict;
use warnings;

use Test::More tests => 65;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Package');
    use_ok('Class::MOP::Module');
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Class::Immutable::Trait');
    use_ok('Class::MOP::Attribute');
    use_ok('Class::MOP::Method');
    use_ok('Class::MOP::Method::Wrapped');
    use_ok('Class::MOP::Method::Inlined');
    use_ok('Class::MOP::Method::Generated');
    use_ok('Class::MOP::Method::Accessor');
    use_ok('Class::MOP::Method::Attribute');
    use_ok('Class::MOP::Method::Reader');
    use_ok('Class::MOP::Method::Writer');
    use_ok('Class::MOP::Method::Clearer');
    use_ok('Class::MOP::Method::Predicate');
    use_ok('Class::MOP::Method::Constructor');
    use_ok('Class::MOP::Instance');
    use_ok('Class::MOP::Object');
}

# make sure we are tracking metaclasses correctly

my %METAS = (
    'Class::MOP::Attribute'         => Class::MOP::Attribute->meta,
    'Class::MOP::Method::Inlined' => Class::MOP::Method::Inlined->meta,
    'Class::MOP::Method::Generated' => Class::MOP::Method::Generated->meta,
    'Class::MOP::Method::Accessor'  => Class::MOP::Method::Accessor->meta,
    'Class::MOP::Method::Reader'  => Class::MOP::Method::Reader->meta,
    'Class::MOP::Method::Writer'  => Class::MOP::Method::Writer->meta,
    'Class::MOP::Method::Clearer'  => Class::MOP::Method::Clearer->meta,
    'Class::MOP::Method::Predicate'  => Class::MOP::Method::Predicate->meta,
    'Class::MOP::Method::Attribute'  => Class::MOP::Method::Attribute->meta,
    'Class::MOP::Method::Constructor' =>
        Class::MOP::Method::Constructor->meta,
    'Class::MOP::Package'         => Class::MOP::Package->meta,
    'Class::MOP::Module'          => Class::MOP::Module->meta,
    'Class::MOP::Class'           => Class::MOP::Class->meta,
    'Class::MOP::Method'          => Class::MOP::Method->meta,
    'Class::MOP::Method::Wrapped' => Class::MOP::Method::Wrapped->meta,
    'Class::MOP::Instance'        => Class::MOP::Instance->meta,
    'Class::MOP::Object'          => Class::MOP::Object->meta,
    'Class::MOP::Class::Immutable::Trait' => Class::MOP::class_of('Class::MOP::Class::Immutable::Trait'),
    'Class::MOP::Class::Immutable::Class::MOP::Class' => Class::MOP::Class::Immutable::Class::MOP::Class->meta,
);

ok( Class::MOP::is_class_loaded($_), '... ' . $_ . ' is loaded' )
    for keys %METAS;

for my $meta (values %METAS) {
    # the trait shouldn't be made immutable, it doesn't actually do anything,
    # and it doesn't even matter because it's not a class that will be
    # instantiated
    if ($meta->name eq 'Class::MOP::Class::Immutable::Trait') {
        ok( $meta->is_mutable(), '... ' . $meta->name . ' is mutable' );
    }
    else {
        ok( $meta->is_immutable(), '... ' . $meta->name . ' is immutable' );
    }
}

is_deeply(
    {Class::MOP::get_all_metaclasses},
    \%METAS,
    '... got all the metaclasses'
);

is_deeply(
    [
        sort { $a->name cmp $b->name } Class::MOP::get_all_metaclass_instances
    ],
    [
        Class::MOP::Attribute->meta,
        Class::MOP::Class->meta,
        Class::MOP::Class::Immutable::Class::MOP::Class->meta,
        Class::MOP::class_of('Class::MOP::Class::Immutable::Trait'),
        Class::MOP::Instance->meta,
        Class::MOP::Method->meta,
        Class::MOP::Method::Accessor->meta,
        Class::MOP::Method::Attribute->meta,
        Class::MOP::Method::Clearer->meta,
        Class::MOP::Method::Constructor->meta,
        Class::MOP::Method::Generated->meta,
        Class::MOP::Method::Inlined->meta,
        Class::MOP::Method::Predicate->meta,
        Class::MOP::Method::Reader->meta,
        Class::MOP::Method::Wrapped->meta,
        Class::MOP::Method::Writer->meta,
        Class::MOP::Module->meta,
        Class::MOP::Object->meta,
        Class::MOP::Package->meta,
    ],
    '... got all the metaclass instances'
);

is_deeply(
    [ sort { $a cmp $b } Class::MOP::get_all_metaclass_names() ],
    [
        sort qw/
            Class::MOP::Attribute
            Class::MOP::Class
            Class::MOP::Class::Immutable::Class::MOP::Class
            Class::MOP::Class::Immutable::Trait
            Class::MOP::Instance
            Class::MOP::Method
            Class::MOP::Method::Accessor
            Class::MOP::Method::Attribute
            Class::MOP::Method::Clearer
            Class::MOP::Method::Constructor
            Class::MOP::Method::Generated
            Class::MOP::Method::Inlined
            Class::MOP::Method::Predicate
            Class::MOP::Method::Reader
            Class::MOP::Method::Wrapped
            Class::MOP::Method::Writer
            Class::MOP::Module
            Class::MOP::Object
            Class::MOP::Package
            /,
    ],
    '... got all the metaclass names'
);

# testing the meta-circularity of the system

is(
    Class::MOP::Class->meta->meta, Class::MOP::Class->meta->meta->meta,
    '... Class::MOP::Class->meta->meta == Class::MOP::Class->meta->meta->meta'
);

is(
    Class::MOP::Class->meta->meta->meta, Class::MOP::Class->meta->meta->meta->meta,
    '... Class::MOP::Class->meta->meta->meta == Class::MOP::Class->meta->meta->meta->meta'
);

is(
    Class::MOP::Class->meta->meta, Class::MOP::Class->meta->meta->meta->meta,
    '... Class::MOP::Class->meta->meta == Class::MOP::Class->meta->meta->meta->meta'
);

is(
    Class::MOP::Class->meta->meta, Class::MOP::Class->meta->meta->meta->meta->meta,
    '... Class::MOP::Class->meta->meta == Class::MOP::Class->meta->meta->meta->meta->meta'
);

isa_ok(Class::MOP::Class->meta, 'Class::MOP::Class');
