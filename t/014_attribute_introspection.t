#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 41;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');        
}

{
    my $attr = Class::MOP::Attribute->new('$test');
    is($attr->meta, Class::MOP::Attribute->meta, '... instance and class both lead to the same meta');
}

{
    my $meta = Class::MOP::Attribute->meta();
    isa_ok($meta, 'Class::MOP::Class');
    
    my @methods = qw(
        meta
        new clone
        
        initialize_instance_slot
        
        name
        has_accessor  accessor
        has_writer    writer
        has_reader    reader
        has_predicate predicate
        has_init_arg  init_arg
        has_default   default
        
        slots
        
        associated_class
        attach_to_class detach_from_class
        
        generate_accessor_method
        generate_reader_method
        generate_writer_method
        generate_predicate_method
        
        process_accessors
        install_accessors
        remove_accessors
        );
        
    is_deeply(
        [ sort @methods ],
        [ sort $meta->get_method_list ],
        '... our method list matches');        
    
    foreach my $method_name (@methods) {
        ok($meta->has_method($method_name), '... Class::MOP::Attribute->has_method(' . $method_name . ')');
    }
    
    my @attributes = qw(
        name accessor reader writer predicate
        init_arg default associated_class
        );

    is_deeply(
        [ sort @attributes ],
        [ sort $meta->get_attribute_list ],
        '... our attribute list matches');
    
    foreach my $attribute_name (@attributes) {
        ok($meta->has_attribute($attribute_name), '... Class::MOP::Attribute->has_attribute(' . $attribute_name . ')');        
    }
    
    # We could add some tests here to make sure that 
    # the attribute have the appropriate 
    # accessor/reader/writer/predicate combinations, 
    # but that is getting a little excessive so I  
    # wont worry about it for now. Maybe if I get 
    # bored I will do it.
}
