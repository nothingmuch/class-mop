#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 58;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Attribute');
}

{
    my $attr = Class::MOP::Attribute->new('$foo');
    isa_ok($attr, 'Class::MOP::Attribute');

    is($attr->name, '$foo', '... $attr->name == $foo');
    ok($attr->has_init_arg, '... $attr does have an init_arg');
    is($attr->init_arg, '$foo', '... $attr init_arg is the name');        
    
    ok(!$attr->has_accessor, '... $attr does not have an accessor');
    ok(!$attr->has_reader, '... $attr does not have an reader');
    ok(!$attr->has_writer, '... $attr does not have an writer');
    ok(!$attr->has_default, '... $attr does not have an default');  
    
    my $attr_clone = $attr->clone();
    isa_ok($attr_clone, 'Class::MOP::Attribute');
    isnt($attr, $attr_clone, '... but they are different instances');
    
    is_deeply($attr, $attr_clone, '... but they are the same inside');
}

{
    my $attr = Class::MOP::Attribute->new('$foo', (
        init_arg => '-foo',
        default  => 'BAR'
    ));
    isa_ok($attr, 'Class::MOP::Attribute');

    is($attr->name, '$foo', '... $attr->name == $foo');
    
    ok($attr->has_init_arg, '... $attr does have an init_arg');
    is($attr->init_arg, '-foo', '... $attr->init_arg == -foo');
    ok($attr->has_default, '... $attr does have an default');    
    is($attr->default, 'BAR', '... $attr->default == BAR');
    
    ok(!$attr->has_accessor, '... $attr does not have an accessor');
    ok(!$attr->has_reader, '... $attr does not have an reader');
    ok(!$attr->has_writer, '... $attr does not have an writer');   
    
    my $attr_clone = $attr->clone();
    isa_ok($attr_clone, 'Class::MOP::Attribute');
    isnt($attr, $attr_clone, '... but they are different instances');
    
    is_deeply($attr, $attr_clone, '... but they are the same inside');                
}

{
    my $attr = Class::MOP::Attribute->new('$foo', (
        accessor => 'foo',
        init_arg => '-foo',
        default  => 'BAR'
    ));
    isa_ok($attr, 'Class::MOP::Attribute');

    is($attr->name, '$foo', '... $attr->name == $foo');
    
    ok($attr->has_init_arg, '... $attr does have an init_arg');
    is($attr->init_arg, '-foo', '... $attr->init_arg == -foo');
    ok($attr->has_default, '... $attr does have an default');    
    is($attr->default, 'BAR', '... $attr->default == BAR');

    ok($attr->has_accessor, '... $attr does have an accessor');    
    is($attr->accessor, 'foo', '... $attr->accessor == foo');
    
    ok(!$attr->has_reader, '... $attr does not have an reader');
    ok(!$attr->has_writer, '... $attr does not have an writer');   
    
    my $attr_clone = $attr->clone();
    isa_ok($attr_clone, 'Class::MOP::Attribute');
    isnt($attr, $attr_clone, '... but they are different instances');
    
    is_deeply($attr, $attr_clone, '... but they are the same inside');                
}

{
    my $attr = Class::MOP::Attribute->new('$foo', (
        reader   => 'get_foo',
        writer   => 'set_foo',        
        init_arg => '-foo',
        default  => 'BAR'
    ));
    isa_ok($attr, 'Class::MOP::Attribute');

    is($attr->name, '$foo', '... $attr->name == $foo');
    
    ok($attr->has_init_arg, '... $attr does have an init_arg');
    is($attr->init_arg, '-foo', '... $attr->init_arg == -foo');
    ok($attr->has_default, '... $attr does have an default');    
    is($attr->default, 'BAR', '... $attr->default == BAR');

    ok($attr->has_reader, '... $attr does have an reader');
    is($attr->reader, 'get_foo', '... $attr->reader == get_foo');    
    ok($attr->has_writer, '... $attr does have an writer');
    is($attr->writer, 'set_foo', '... $attr->writer == set_foo');    

    ok(!$attr->has_accessor, '... $attr does not have an accessor'); 
    
    my $attr_clone = $attr->clone();
    isa_ok($attr_clone, 'Class::MOP::Attribute');
    isnt($attr, $attr_clone, '... but they are different instances');
    
    is_deeply($attr, $attr_clone, '... but they are the same inside');       
}

{
    my $attr = Class::MOP::Attribute->new('$foo');
    isa_ok($attr, 'Class::MOP::Attribute');
    
    my $attr_clone = $attr->clone('name' => '$bar');
    isa_ok($attr_clone, 'Class::MOP::Attribute');
    isnt($attr, $attr_clone, '... but they are different instances');
    
    isnt($attr->name, $attr_clone->name, '... we changes the name parameter');
    
    is($attr->name, '$foo', '... $attr->name == $foo');
    is($attr_clone->name, '$bar', '... $attr_clone->name == $bar');    
}

