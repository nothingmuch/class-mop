#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 204;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Package');
    use_ok('Class::MOP::Module');
}

{
    my $class = Class::MOP::Class->initialize('Foo');
    is($class->meta, Class::MOP::Class->meta, '... instance and class both lead to the same meta');
}

my $class_mop_class_meta = Class::MOP::Class->meta();
isa_ok($class_mop_class_meta, 'Class::MOP::Class');

my $class_mop_package_meta = Class::MOP::Package->meta();
isa_ok($class_mop_package_meta, 'Class::MOP::Package');

my $class_mop_module_meta = Class::MOP::Module->meta();
isa_ok($class_mop_module_meta, 'Class::MOP::Module');

my @class_mop_package_methods = qw(

    initialize

    name
    namespace

    add_package_symbol get_package_symbol has_package_symbol remove_package_symbol
    list_all_package_symbols get_all_package_symbols remove_package_glob

    _deconstruct_variable_name
);

my @class_mop_module_methods = qw(

    version authority identifier
);

my @class_mop_class_methods = qw(

    initialize reinitialize create
    
    update_package_cache_flag
    reset_package_cache_flag

    create_anon_class is_anon_class

    instance_metaclass get_meta_instance
    new_object clone_object
    construct_instance construct_class_instance clone_instance
    rebless_instance
    check_metaclass_compatability

    attribute_metaclass method_metaclass

    superclasses subclasses class_precedence_list linearized_isa

    has_method get_method add_method remove_method alias_method
    get_method_list get_method_map compute_all_applicable_methods
        find_method_by_name find_all_methods_by_name find_next_method_by_name

        add_before_method_modifier add_after_method_modifier add_around_method_modifier

    has_attribute get_attribute add_attribute remove_attribute
    get_attribute_list get_attribute_map compute_all_applicable_attributes find_attribute_by_name

    is_mutable is_immutable make_mutable make_immutable create_immutable_transformer
    get_immutable_options get_immutable_transformer

    DESTROY
);

# check the class ...

is_deeply([ sort @class_mop_class_methods ], [ sort $class_mop_class_meta->get_method_list ], '... got the correct method list for class');

foreach my $method_name (@class_mop_class_methods) {
    ok($class_mop_class_meta->has_method($method_name), '... Class::MOP::Class->has_method(' . $method_name . ')');
    {
        no strict 'refs';
        is($class_mop_class_meta->get_method($method_name)->body,
           \&{'Class::MOP::Class::' . $method_name},
           '... Class::MOP::Class->get_method(' . $method_name . ') == &Class::MOP::Class::' . $method_name);
    }
}

## check the package ....

is_deeply([ sort @class_mop_package_methods ], [ sort $class_mop_package_meta->get_method_list ], '... got the correct method list for package');

foreach my $method_name (@class_mop_package_methods) {
    ok($class_mop_package_meta->has_method($method_name), '... Class::MOP::Package->has_method(' . $method_name . ')');
    {
        no strict 'refs';
        is($class_mop_package_meta->get_method($method_name)->body,
           \&{'Class::MOP::Package::' . $method_name},
           '... Class::MOP::Package->get_method(' . $method_name . ') == &Class::MOP::Package::' . $method_name);
    }
}

## check the module ....

is_deeply([ sort @class_mop_module_methods ], [ sort $class_mop_module_meta->get_method_list ], '... got the correct method list for module');

foreach my $method_name (@class_mop_module_methods) {
    ok($class_mop_module_meta->has_method($method_name), '... Class::MOP::Module->has_method(' . $method_name . ')');
    {
        no strict 'refs';
        is($class_mop_module_meta->get_method($method_name)->body,
           \&{'Class::MOP::Module::' . $method_name},
           '... Class::MOP::Module->get_method(' . $method_name . ') == &Class::MOP::Module::' . $method_name);
    }
}


# check for imported functions which are not methods

foreach my $non_method_name (qw(
    confess
    blessed
    subname
    svref_2object
    )) {
    ok(!$class_mop_class_meta->has_method($non_method_name), '... NOT Class::MOP::Class->has_method(' . $non_method_name . ')');
}

# check for the right attributes

my @class_mop_package_attributes = (
    '$!package',
    '%!namespace',
);

my @class_mop_module_attributes = (
    '$!version',
    '$!authority'
);

my @class_mop_class_attributes = (
    '@!superclasses',
    '%!methods',
    '%!attributes',
    '$!attribute_metaclass',
    '$!method_metaclass',
    '$!instance_metaclass'
);

# check class

is_deeply(
    [ sort @class_mop_class_attributes ],
    [ sort $class_mop_class_meta->get_attribute_list ],
    '... got the right list of attributes');

is_deeply(
    [ sort @class_mop_class_attributes ],
    [ sort keys %{$class_mop_class_meta->get_attribute_map} ],
    '... got the right list of attributes');

foreach my $attribute_name (@class_mop_class_attributes) {
    ok($class_mop_class_meta->has_attribute($attribute_name), '... Class::MOP::Class->has_attribute(' . $attribute_name . ')');
    isa_ok($class_mop_class_meta->get_attribute($attribute_name), 'Class::MOP::Attribute');
}

# check module

is_deeply(
    [ sort @class_mop_package_attributes ],
    [ sort $class_mop_package_meta->get_attribute_list ],
    '... got the right list of attributes');

is_deeply(
    [ sort @class_mop_package_attributes ],
    [ sort keys %{$class_mop_package_meta->get_attribute_map} ],
    '... got the right list of attributes');

foreach my $attribute_name (@class_mop_package_attributes) {
    ok($class_mop_package_meta->has_attribute($attribute_name), '... Class::MOP::Package->has_attribute(' . $attribute_name . ')');
    isa_ok($class_mop_package_meta->get_attribute($attribute_name), 'Class::MOP::Attribute');
}

# check package

is_deeply(
    [ sort @class_mop_module_attributes ],
    [ sort $class_mop_module_meta->get_attribute_list ],
    '... got the right list of attributes');

is_deeply(
    [ sort @class_mop_module_attributes ],
    [ sort keys %{$class_mop_module_meta->get_attribute_map} ],
    '... got the right list of attributes');

foreach my $attribute_name (@class_mop_module_attributes) {
    ok($class_mop_module_meta->has_attribute($attribute_name), '... Class::MOP::Module->has_attribute(' . $attribute_name . ')');
    isa_ok($class_mop_module_meta->get_attribute($attribute_name), 'Class::MOP::Attribute');
}

## check the attributes themselves

# ... package

ok($class_mop_package_meta->get_attribute('$!package')->has_reader, '... Class::MOP::Class $!package has a reader');
is(ref($class_mop_package_meta->get_attribute('$!package')->reader), 'HASH', '... Class::MOP::Class $!package\'s a reader is { name => sub { ... } }');

ok($class_mop_package_meta->get_attribute('$!package')->has_init_arg, '... Class::MOP::Class $!package has a init_arg');
is($class_mop_package_meta->get_attribute('$!package')->init_arg, 'package', '... Class::MOP::Class $!package\'s a init_arg is package');

# ... class

ok($class_mop_class_meta->get_attribute('%!attributes')->has_reader, '... Class::MOP::Class %!attributes has a reader');
is_deeply($class_mop_class_meta->get_attribute('%!attributes')->reader,
   { 'get_attribute_map' => \&Class::MOP::Class::get_attribute_map },
   '... Class::MOP::Class %!attributes\'s a reader is &get_attribute_map');

ok($class_mop_class_meta->get_attribute('%!attributes')->has_init_arg, '... Class::MOP::Class %!attributes has a init_arg');
is($class_mop_class_meta->get_attribute('%!attributes')->init_arg,
  'attributes',
  '... Class::MOP::Class %!attributes\'s a init_arg is attributes');

ok($class_mop_class_meta->get_attribute('%!attributes')->has_default, '... Class::MOP::Class %!attributes has a default');
is_deeply($class_mop_class_meta->get_attribute('%!attributes')->default('Foo'),
         {},
         '... Class::MOP::Class %!attributes\'s a default of {}');

ok($class_mop_class_meta->get_attribute('$!attribute_metaclass')->has_reader, '... Class::MOP::Class $!attribute_metaclass has a reader');
is_deeply($class_mop_class_meta->get_attribute('$!attribute_metaclass')->reader,
   { 'attribute_metaclass' => \&Class::MOP::Class::attribute_metaclass },
  '... Class::MOP::Class $!attribute_metaclass\'s a reader is &attribute_metaclass');

ok($class_mop_class_meta->get_attribute('$!attribute_metaclass')->has_init_arg, '... Class::MOP::Class $!attribute_metaclass has a init_arg');
is($class_mop_class_meta->get_attribute('$!attribute_metaclass')->init_arg,
   'attribute_metaclass',
   '... Class::MOP::Class $!attribute_metaclass\'s a init_arg is attribute_metaclass');

ok($class_mop_class_meta->get_attribute('$!attribute_metaclass')->has_default, '... Class::MOP::Class $!attribute_metaclass has a default');
is($class_mop_class_meta->get_attribute('$!attribute_metaclass')->default,
  'Class::MOP::Attribute',
  '... Class::MOP::Class $!attribute_metaclass\'s a default is Class::MOP:::Attribute');

ok($class_mop_class_meta->get_attribute('$!method_metaclass')->has_reader, '... Class::MOP::Class $!method_metaclass has a reader');
is_deeply($class_mop_class_meta->get_attribute('$!method_metaclass')->reader,
   { 'method_metaclass' => \&Class::MOP::Class::method_metaclass },
   '... Class::MOP::Class $!method_metaclass\'s a reader is &method_metaclass');

ok($class_mop_class_meta->get_attribute('$!method_metaclass')->has_init_arg, '... Class::MOP::Class $!method_metaclass has a init_arg');
is($class_mop_class_meta->get_attribute('$!method_metaclass')->init_arg,
  'method_metaclass',
  '... Class::MOP::Class $:method_metaclass\'s init_arg is method_metaclass');

ok($class_mop_class_meta->get_attribute('$!method_metaclass')->has_default, '... Class::MOP::Class $!method_metaclass has a default');
is($class_mop_class_meta->get_attribute('$!method_metaclass')->default,
   'Class::MOP::Method',
  '... Class::MOP::Class $!method_metaclass\'s a default is Class::MOP:::Method');

# check the values of some of the methods

is($class_mop_class_meta->name, 'Class::MOP::Class', '... Class::MOP::Class->name');
is($class_mop_class_meta->version, $Class::MOP::Class::VERSION, '... Class::MOP::Class->version');

ok($class_mop_class_meta->has_package_symbol('$VERSION'), '... Class::MOP::Class->has_package_symbol($VERSION)');
is(${$class_mop_class_meta->get_package_symbol('$VERSION')},
   $Class::MOP::Class::VERSION,
   '... Class::MOP::Class->get_package_symbol($VERSION)');

is_deeply(
    [ $class_mop_class_meta->superclasses ],
    [ qw/Class::MOP::Module/ ],
    '... Class::MOP::Class->superclasses == [ Class::MOP::Module ]');

is_deeply(
    [ $class_mop_class_meta->class_precedence_list ],
    [ qw/
        Class::MOP::Class
        Class::MOP::Module
        Class::MOP::Package
        Class::MOP::Object
    / ],
    '... Class::MOP::Class->class_precedence_list == [ Class::MOP::Class Class::MOP::Module Class::MOP::Package ]');

is($class_mop_class_meta->attribute_metaclass, 'Class::MOP::Attribute', '... got the right value for attribute_metaclass');
is($class_mop_class_meta->method_metaclass, 'Class::MOP::Method', '... got the right value for method_metaclass');
is($class_mop_class_meta->instance_metaclass, 'Class::MOP::Instance', '... got the right value for instance_metaclass');

