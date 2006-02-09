#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 115;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Class');        
}

my $meta = Class::MOP::Class->meta();
isa_ok($meta, 'Class::MOP::Class');

my @methods = qw(
    meta
    
    initialize create
    
    new_object clone_object
    construct_instance construct_class_instance clone_instance
    check_metaclass_compatability
    
    name version
    
    attribute_metaclass method_metaclass
    
    superclasses class_precedence_list
    
    has_method get_method add_method remove_method 
    get_method_list compute_all_applicable_methods find_all_methods_by_name
    
    has_attribute get_attribute add_attribute remove_attribute
    get_attribute_list get_attribute_map compute_all_applicable_attributes
    
    add_package_variable get_package_variable has_package_variable remove_package_variable
    );
    
is_deeply([ sort @methods ], [ sort $meta->get_method_list ], '... got the correct method list');

foreach my $method_name (@methods) {
    ok($meta->has_method($method_name), '... Class::MOP::Class->has_method(' . $method_name . ')');
    {
        no strict 'refs';
        is($meta->get_method($method_name), 
           \&{'Class::MOP::Class::' . $method_name},
           '... Class::MOP::Class->get_method(' . $method_name . ') == &Class::MOP::Class::' . $method_name);        
    }
}

# check for imported functions which are not methods

foreach my $non_method_name (qw(
    confess
    blessed reftype
    subname
    svref_2object
    )) {
    ok(!$meta->has_method($non_method_name), '... NOT Class::MOP::Class->has_method(' . $non_method_name . ')');        
}

# check for the right attributes

my @attributes = ('$:package', '%:attributes', '$:attribute_metaclass', '$:method_metaclass');

is_deeply(
    [ sort @attributes ],
    [ sort $meta->get_attribute_list ],
    '... got the right list of attributes');
    
is_deeply(
    [ sort @attributes ],
    [ sort keys %{$meta->get_attribute_map} ],
    '... got the right list of attributes');    

foreach my $attribute_name (@attributes) {
    ok($meta->has_attribute($attribute_name), '... Class::MOP::Class->has_attribute(' . $attribute_name . ')');        
    isa_ok($meta->get_attribute($attribute_name), 'Class::MOP::Attribute');            
}

## check the attributes themselves

ok($meta->get_attribute('$:package')->has_reader, '... Class::MOP::Class $:package has a reader');
is($meta->get_attribute('$:package')->reader, 'name', '... Class::MOP::Class $:package\'s a reader is &name');

ok($meta->get_attribute('$:package')->has_init_arg, '... Class::MOP::Class $:package has a init_arg');
is($meta->get_attribute('$:package')->init_arg, ':package', '... Class::MOP::Class $:package\'s a init_arg is :package');

ok($meta->get_attribute('%:attributes')->has_reader, '... Class::MOP::Class %:attributes has a reader');
is($meta->get_attribute('%:attributes')->reader, 
   'get_attribute_map', 
   '... Class::MOP::Class %:attributes\'s a reader is &get_attribute_map');
   
ok($meta->get_attribute('%:attributes')->has_init_arg, '... Class::MOP::Class %:attributes has a init_arg');
is($meta->get_attribute('%:attributes')->init_arg, 
  ':attributes', 
  '... Class::MOP::Class %:attributes\'s a init_arg is :attributes');   
  
ok($meta->get_attribute('%:attributes')->has_default, '... Class::MOP::Class %:attributes has a default');
is_deeply($meta->get_attribute('%:attributes')->default, 
         {}, 
         '... Class::MOP::Class %:attributes\'s a default of {}');  

ok($meta->get_attribute('$:attribute_metaclass')->has_reader, '... Class::MOP::Class $:attribute_metaclass has a reader');
is($meta->get_attribute('$:attribute_metaclass')->reader, 
  'attribute_metaclass', 
  '... Class::MOP::Class $:attribute_metaclass\'s a reader is &attribute_metaclass');
  
ok($meta->get_attribute('$:attribute_metaclass')->has_init_arg, '... Class::MOP::Class $:attribute_metaclass has a init_arg');
is($meta->get_attribute('$:attribute_metaclass')->init_arg, 
   ':attribute_metaclass', 
   '... Class::MOP::Class $:attribute_metaclass\'s a init_arg is :attribute_metaclass');  
   
ok($meta->get_attribute('$:attribute_metaclass')->has_default, '... Class::MOP::Class $:attribute_metaclass has a default');
is($meta->get_attribute('$:attribute_metaclass')->default, 
  'Class::MOP::Attribute', 
  '... Class::MOP::Class $:attribute_metaclass\'s a default is Class::MOP:::Attribute');   
  
ok($meta->get_attribute('$:method_metaclass')->has_reader, '... Class::MOP::Class $:method_metaclass has a reader');
is($meta->get_attribute('$:method_metaclass')->reader, 
   'method_metaclass', 
   '... Class::MOP::Class $:method_metaclass\'s a reader is &method_metaclass');  
   
ok($meta->get_attribute('$:method_metaclass')->has_init_arg, '... Class::MOP::Class $:method_metaclass has a init_arg');
is($meta->get_attribute('$:method_metaclass')->init_arg, 
  ':method_metaclass', 
  '... Class::MOP::Class $:method_metaclass\'s init_arg is :method_metaclass');   
  
ok($meta->get_attribute('$:method_metaclass')->has_default, '... Class::MOP::Class $:method_metaclass has a default');
is($meta->get_attribute('$:method_metaclass')->default, 
   'Class::MOP::Method', 
  '... Class::MOP::Class $:method_metaclass\'s a default is Class::MOP:::Method');  

# check the values of some of the methods

is($meta->name, 'Class::MOP::Class', '... Class::MOP::Class->name');
is($meta->version, $Class::MOP::Class::VERSION, '... Class::MOP::Class->version');

ok($meta->has_package_variable('$VERSION'), '... Class::MOP::Class->has_package_variable($VERSION)');
is(${$meta->get_package_variable('$VERSION')}, 
   $Class::MOP::Class::VERSION, 
   '... Class::MOP::Class->get_package_variable($VERSION)');

is_deeply(
    [ $meta->superclasses ], 
    [], 
    '... Class::MOP::Class->superclasses == []');
    
is_deeply(
    [ $meta->class_precedence_list ], 
    [ 'Class::MOP::Class' ], 
    '... Class::MOP::Class->class_precedence_list == []');

is($meta->attribute_metaclass, 'Class::MOP::Attribute', '... got the right value for attribute_metaclass');
is($meta->method_metaclass, 'Class::MOP::Method', '... got the right value for method_metaclass');

