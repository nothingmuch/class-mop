#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 60;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Class');        
}

my $meta = Class::MOP::Class->meta();
isa_ok($meta, 'Class::MOP::Class');

foreach my $method_name (qw(
    meta
    
    initialize create
    
    name version
    
    superclasses class_precedence_list
    
    has_method get_method add_method remove_method 
    get_method_list compute_all_applicable_methods find_all_methods_by_name
    
    has_attribute get_attribute add_attribute remove_attribute
    get_attribute_list compute_all_applicable_attributes
    )) {
    ok($meta->has_method($method_name), '... Class::MOP::Class->has_method(' . $method_name . ')');
    {
        no strict 'refs';
        is($meta->get_method($method_name), 
           \&{'Class::MOP::Class::' . $method_name},
           '... Class::MOP::Class->get_method(' . $method_name . ') == &Class::MOP::Class::' . $method_name);        
    }
}

foreach my $non_method_name (qw(
    confess
    blessed reftype
    subname
    svref_2object
    )) {
    ok(!$meta->has_method($non_method_name), '... NOT Class::MOP::Class->has_method(' . $non_method_name . ')');        
}

foreach my $attribute_name (
    '$:package', '%:attributes', 
    '$:attribute_metaclass', '$:method_metaclass'
    ) {
    ok($meta->has_attribute($attribute_name), '... Class::MOP::Class->has_attribute(' . $attribute_name . ')');        
    isa_ok($meta->get_attribute($attribute_name), 'Class::MOP::Attribute');            
}

is($meta->name, 'Class::MOP::Class', '... Class::MOP::Class->name');
is($meta->version, $Class::MOP::Class::VERSION, '... Class::MOP::Class->version');

is_deeply(
    [ $meta->superclasses ], 
    [], 
    '... Class::MOP::Class->superclasses == []');
    
is_deeply(
    [ $meta->class_precedence_list ], 
    [ 'Class::MOP::Class' ], 
    '... Class::MOP::Class->class_precedence_list == []');

