#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 53;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
}

{
    dies_ok {
        Class::MOP::Class->initialize();
    } '... initialize requires a name parameter';
    
    dies_ok {
        Class::MOP::Class->initialize('');
    } '... initialize requires a name valid parameter';    

    dies_ok {
        Class::MOP::Class->initialize(bless {} => 'Foo');
    } '... initialize requires an unblessed parameter'
}

{
    dies_ok {
        Class::MOP::Class->construct_class_instance();
    } '... construct_class_instance requires an :package parameter';
    
    dies_ok {
        Class::MOP::Class->construct_class_instance(':package' => undef);
    } '... construct_class_instance requires a defined :package parameter';     
    
    dies_ok {
        Class::MOP::Class->construct_class_instance(':package' => '');
    } '... construct_class_instance requires a valid :package parameter'; 
}


{
    dies_ok {
        Class::MOP::Class->create();
    } '... create requires an package_name parameter';
    
    dies_ok {
        Class::MOP::Class->create(undef);
    } '... create requires a defined package_name parameter';    
    
    dies_ok {
        Class::MOP::Class->create('');
    } '... create requires a valid package_name parameter';    
    
    throws_ok {
        Class::MOP::Class->create('+++');
    } qr/^creation of \+\+\+ failed/, '... create requires a valid package_name parameter';    
     
}

{
    dies_ok {
        Class::MOP::Class->clone_object(1);
    } '... can only clone instances';
    
    dies_ok {
        Class::MOP::Class->clone_instance(1);
    } '... can only clone instances';    
}

{
    dies_ok {
        Class::MOP::Class->add_method();
    } '... add_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->add_method('');
    } '... add_method dies as expected';   

    dies_ok {
        Class::MOP::Class->add_method('foo' => 'foo');
    } '... add_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->add_method('foo' => []);
    } '... add_method dies as expected';     
}

{
    dies_ok {
        Class::MOP::Class->alias_method();
    } '... alias_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->alias_method('');
    } '... alias_method dies as expected';   

    dies_ok {
        Class::MOP::Class->alias_method('foo' => 'foo');
    } '... alias_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->alias_method('foo' => []);
    } '... alias_method dies as expected';     
}

{
    dies_ok {
        Class::MOP::Class->has_method();
    } '... has_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->has_method('');
    } '... has_method dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->get_method();
    } '... get_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->get_method('');
    } '... get_method dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->remove_method();
    } '... remove_method dies as expected';
    
    dies_ok {
        Class::MOP::Class->remove_method('');
    } '... remove_method dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->find_all_methods_by_name();
    } '... find_all_methods_by_name dies as expected';
    
    dies_ok {
        Class::MOP::Class->find_all_methods_by_name('');
    } '... find_all_methods_by_name dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->add_attribute(bless {} => 'Foo');
    } '... add_attribute dies as expected';
}


{
    dies_ok {
        Class::MOP::Class->has_attribute();
    } '... has_attribute dies as expected';
    
    dies_ok {
        Class::MOP::Class->has_attribute('');
    } '... has_attribute dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->get_attribute();
    } '... get_attribute dies as expected';
    
    dies_ok {
        Class::MOP::Class->get_attribute('');
    } '... get_attribute dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->remove_attribute();
    } '... remove_attribute dies as expected';
    
    dies_ok {
        Class::MOP::Class->remove_attribute('');
    } '... remove_attribute dies as expected';
}

{
    dies_ok {
        Class::MOP::Class->add_package_variable();
    } '... add_package_variable dies as expected';
    
    dies_ok {
        Class::MOP::Class->add_package_variable('');
    } '... add_package_variable dies as expected';
    
    dies_ok {
        Class::MOP::Class->add_package_variable('foo');
    } '... add_package_variable dies as expected';  
    
    dies_ok {
        Class::MOP::Class->add_package_variable('&foo');
    } '... add_package_variable dies as expected';      
    
    throws_ok {
        Class::MOP::Class->meta->add_package_variable('@-');
    } qr/^Could not create package variable \(\@\-\) because/, 
      '... add_package_variable dies as expected';    
}

{
    dies_ok {
        Class::MOP::Class->has_package_variable();
    } '... has_package_variable dies as expected';

    dies_ok {
        Class::MOP::Class->has_package_variable('');
    } '... has_package_variable dies as expected';

    dies_ok {
        Class::MOP::Class->has_package_variable('foo');
    } '... has_package_variable dies as expected';  

    dies_ok {
        Class::MOP::Class->has_package_variable('&foo');
    } '... has_package_variable dies as expected';    
}

{
    dies_ok {
        Class::MOP::Class->get_package_variable();
    } '... get_package_variable dies as expected';

    dies_ok {
        Class::MOP::Class->get_package_variable('');
    } '... get_package_variable dies as expected';

    dies_ok {
        Class::MOP::Class->get_package_variable('foo');
    } '... get_package_variable dies as expected';  

    dies_ok {
        Class::MOP::Class->get_package_variable('&foo');
    } '... get_package_variable dies as expected';    
}

{
    dies_ok {
        Class::MOP::Class->remove_package_variable();
    } '... remove_package_variable dies as expected';

    dies_ok {
        Class::MOP::Class->remove_package_variable('');
    } '... remove_package_variable dies as expected';

    dies_ok {
        Class::MOP::Class->remove_package_variable('foo');
    } '... remove_package_variable dies as expected';  

    dies_ok {
        Class::MOP::Class->remove_package_variable('&foo');
    } '... remove_package_variable dies as expected';    
}

