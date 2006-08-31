#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 22;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Attribute');
    use_ok('Class::MOP::Method');            
    use_ok('Class::MOP::Instance');            
    use_ok('Class::MOP::Object');                
}

# make sure we are tracking metaclasses correctly

my %METAS = (
    'Class::MOP::Attribute'           => Class::MOP::Attribute->meta, 
    'Class::MOP::Attribute::Accessor' => Class::MOP::Attribute::Accessor->meta,     
    'Class::MOP::Package'             => Class::MOP::Package->meta, 
    'Class::MOP::Module'              => Class::MOP::Module->meta,     
    'Class::MOP::Class'               => Class::MOP::Class->meta, 
    'Class::MOP::Method'              => Class::MOP::Method->meta,  
    'Class::MOP::Method::Wrapped'     => Class::MOP::Method::Wrapped->meta,      
    'Class::MOP::Instance'            => Class::MOP::Instance->meta,   
    'Class::MOP::Object'              => Class::MOP::Object->meta,          
);

ok($_->is_immutable(), '... ' . $_->name . ' is immutable') for values %METAS;

is_deeply(
    { Class::MOP::get_all_metaclasses },
    \%METAS,
    '... got all the metaclasses');

is_deeply(
    [ sort { $a->name cmp $b->name } Class::MOP::get_all_metaclass_instances ],
    [ 
        Class::MOP::Attribute->meta,
        Class::MOP::Attribute::Accessor->meta, 
        Class::MOP::Class->meta, 
        Class::MOP::Instance->meta,         
        Class::MOP::Method->meta,
        Class::MOP::Method::Wrapped->meta,
        Class::MOP::Module->meta, 
        Class::MOP::Object->meta,          
        Class::MOP::Package->meta,              
    ],
    '... got all the metaclass instances');

is_deeply(
    [ sort { $a cmp $b } Class::MOP::get_all_metaclass_names() ],
    [ qw/
        Class::MOP::Attribute   
        Class::MOP::Attribute::Accessor    
        Class::MOP::Class
        Class::MOP::Instance
        Class::MOP::Method
        Class::MOP::Method::Wrapped
        Class::MOP::Module  
        Class::MOP::Object        
        Class::MOP::Package                      
    / ],
    '... got all the metaclass names');
    
is_deeply(
    [ map { $_->meta->identifier } sort { $a cmp $b } Class::MOP::get_all_metaclass_names() ],
    [ 
       "Class::MOP::Attribute-"           . $Class::MOP::Attribute::VERSION           . "-cpan:STEVAN",  
       "Class::MOP::Attribute::Accessor-" . $Class::MOP::Attribute::Accessor::VERSION . "-cpan:STEVAN",          
       "Class::MOP::Class-"               . $Class::MOP::Class::VERSION               . "-cpan:STEVAN",
       "Class::MOP::Instance-"            . $Class::MOP::Instance::VERSION            . "-cpan:STEVAN",
       "Class::MOP::Method-"              . $Class::MOP::Method::VERSION              . "-cpan:STEVAN",
       "Class::MOP::Method::Wrapped-"     . $Class::MOP::Method::Wrapped::VERSION     . "-cpan:STEVAN",       
       "Class::MOP::Module-"              . $Class::MOP::Module::VERSION              . "-cpan:STEVAN",
       "Class::MOP::Object-"              . $Class::MOP::Object::VERSION              . "-cpan:STEVAN",
       "Class::MOP::Package-"             . $Class::MOP::Package::VERSION             . "-cpan:STEVAN",
    ],
    '... got all the metaclass identifiers');    
        
# testing the meta-circularity of the system

is(Class::MOP::Class->meta, Class::MOP::Class->meta->meta, 
   '... Class::MOP::Class->meta == Class::MOP::Class->meta->meta');
   
is(Class::MOP::Class->meta, Class::MOP::Class->meta->meta->meta, 
  '... Class::MOP::Class->meta == Class::MOP::Class->meta->meta->meta');   

is(Class::MOP::Class->meta, Class::MOP::Class->meta->meta->meta->meta, 
   '... Class::MOP::Class->meta == Class::MOP::Class->meta->meta->meta->meta');  



