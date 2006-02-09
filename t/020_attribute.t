#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 62;
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

# NOTE:
# the next three tests once tested that 
# the code would fail, but we lifted the 
# restriction so you can have an accessor 
# along with a reader/writer pair (I mean 
# why not really). So now they test that 
# it works, which is kinda silly, but it 
# tests the API change, so I keep it.

lives_ok {
    Class::MOP::Attribute->new('$foo', (
        accessor => 'foo',
        reader   => 'get_foo',
    ));
} '... can create accessors with reader/writers';

lives_ok {
    Class::MOP::Attribute->new('$foo', (
        accessor => 'foo',
        writer   => 'set_foo',
    ));
} '... can create accessors with reader/writers';

lives_ok {
    Class::MOP::Attribute->new('$foo', (
        accessor => 'foo',
        reader   => 'get_foo',        
        writer   => 'set_foo',
    ));
} '... can create accessors with reader/writers';

dies_ok {
    Class::MOP::Attribute->new();
} '... no name argument';

dies_ok {
    Class::MOP::Attribute->new('');
} '... bad name argument';

dies_ok {
    Class::MOP::Attribute->new(0);
} '... bad name argument';

dies_ok {
    Class::MOP::Attribute->install_accessors();
} '... bad install_accessors argument';

dies_ok {
    Class::MOP::Attribute->install_accessors(bless {} => 'Fail');
} '... bad install_accessors argument';

dies_ok {
    Class::MOP::Attribute->remove_accessors();
} '... bad remove_accessors argument';

dies_ok {
    Class::MOP::Attribute->remove_accessors(bless {} => 'Fail');
} '... bad remove_accessors argument';
