#!/usr/bin/perl

use strict;
use warnings;

use Scalar::Util;

use Test::More tests => 32;

BEGIN {
    use_ok('Class::MOP');
}

=pod

This tests that when an attribute of the same name
is added to a class, that it will remove the old
one first.

=cut

{
    package Foo;
    use metaclass;
    
    Foo->meta->add_attribute('bar' => 
        reader => 'get_bar',
        writer => 'set_bar',
    );
    
    ::can_ok('Foo', 'get_bar');
    ::can_ok('Foo', 'set_bar');    
    ::ok(Foo->meta->has_attribute('bar'), '... Foo has the attribute bar');
    
    my $bar_attr = Foo->meta->get_attribute('bar');
    
    ::is($bar_attr->reader, 'get_bar', '... the bar attribute has the reader get_bar');
    ::is($bar_attr->writer, 'set_bar', '... the bar attribute has the writer set_bar');    
    ::is($bar_attr->associated_class, Foo->meta, '... and the bar attribute is associated with Foo->meta');
    
    ::is($bar_attr->get_read_method,  'get_bar', '... $attr does have an read method');
    ::is($bar_attr->get_write_method, 'set_bar', '... $attr does have an write method');    
    
    {
        my $reader = $bar_attr->get_read_method_ref;
        my $writer = $bar_attr->get_write_method_ref;        
        
        ::isa_ok($reader, 'Class::MOP::Method');
        ::isa_ok($writer, 'Class::MOP::Method');        

        ::is($reader->fully_qualified_name, 'Foo::get_bar', '... it is the sub we are looking for');
        ::is($writer->fully_qualified_name, 'Foo::set_bar', '... it is the sub we are looking for');
        
        ::is(Scalar::Util::reftype($reader->body), 'CODE', '... it is a plain old sub');
        ::is(Scalar::Util::reftype($writer->body), 'CODE', '... it is a plain old sub');                
    }    
    
    Foo->meta->add_attribute('bar' => 
        reader => 'assign_bar'
    );    

    ::ok(!Foo->can('get_bar'), '... Foo no longer has the get_bar method');
    ::ok(!Foo->can('set_bar'), '... Foo no longer has the set_bar method');    
    ::can_ok('Foo', 'assign_bar');    
    ::ok(Foo->meta->has_attribute('bar'), '... Foo still has the attribute bar');
    
    my $bar_attr2 = Foo->meta->get_attribute('bar');
    
    ::is($bar_attr2->get_read_method,  'assign_bar', '... $attr does have an read method');
    ::ok(!$bar_attr2->get_write_method, '... $attr does have an write method');    
    
    {
        my $reader = $bar_attr2->get_read_method_ref;
        my $writer = $bar_attr2->get_write_method_ref;        
        
        ::isa_ok($reader, 'Class::MOP::Method');
        ::ok(!Scalar::Util::blessed($writer), '... the writer method is not blessed though');    
        
        ::is($reader->fully_qualified_name, 'Foo::assign_bar', '... it is the sub we are looking for');            
        
        ::is(Scalar::Util::reftype($reader->body), 'CODE', '... it is a plain old sub');
        ::is(Scalar::Util::reftype($writer), 'CODE', '... it is a plain old sub');                
    }    
    
    ::isnt($bar_attr, $bar_attr2, '... this is a new bar attribute');
    ::isnt($bar_attr->associated_class, Foo->meta, '... and the old bar attribute is no longer associated with Foo->meta');    
    
    ::is($bar_attr2->associated_class, Foo->meta, '... and the new bar attribute *is* associated with Foo->meta');    
    
    ::isnt($bar_attr2->reader, 'get_bar', '... the bar attribute no longer has the reader get_bar');
    ::isnt($bar_attr2->reader, 'set_bar', '... the bar attribute no longer has the reader set_bar');    
    ::is($bar_attr2->reader, 'assign_bar', '... the bar attribute now has the reader assign_bar');    
}

