#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 42;

BEGIN {
    use_ok('Class::MOP');
    use_ok('Class::MOP::Package');    
    use_ok('Class::MOP::Module');        
    use_ok('Class::MOP::Class');
    use_ok('Class::MOP::Immutable');    
    use_ok('Class::MOP::Attribute');
    use_ok('Class::MOP::Method');  
    use_ok('Class::MOP::Method::Wrapped');                
    use_ok('Class::MOP::Method::Generated');     
    use_ok('Class::MOP::Method::Accessor');                    
    use_ok('Class::MOP::Method::Constructor');                    
    use_ok('Class::MOP::Instance');            
    use_ok('Class::MOP::Object');                
}

# make sure we are tracking metaclasses correctly

my $CLASS_MOP_CLASS_IMMUTABLE_CLASS = 'Class::MOP::Class::__ANON__::SERIAL::1';

my %METAS = (
    'Class::MOP::Attribute'           => Class::MOP::Attribute->meta, 
    'Class::MOP::Method::Generated'   => Class::MOP::Method::Generated->meta,
    'Class::MOP::Method::Accessor'    => Class::MOP::Method::Accessor->meta,  
    'Class::MOP::Method::Constructor' => Class::MOP::Method::Constructor->meta,         
    'Class::MOP::Package'             => Class::MOP::Package->meta, 
    'Class::MOP::Module'              => Class::MOP::Module->meta,     
    'Class::MOP::Class'               => Class::MOP::Class->meta,      
    'Class::MOP::Method'              => Class::MOP::Method->meta,  
    'Class::MOP::Method::Wrapped'     => Class::MOP::Method::Wrapped->meta,      
    'Class::MOP::Instance'            => Class::MOP::Instance->meta,   
    'Class::MOP::Object'              => Class::MOP::Object->meta,  
);

ok(Class::MOP::is_class_loaded($_), '... ' . $_ . ' is loaded') for keys %METAS;

ok($_->is_immutable(), '... ' . $_->name . ' is immutable') for values %METAS;

is_deeply(
    { Class::MOP::get_all_metaclasses },
    {
        %METAS,
        $CLASS_MOP_CLASS_IMMUTABLE_CLASS => $CLASS_MOP_CLASS_IMMUTABLE_CLASS->meta
    },
    '... got all the metaclasses');

is_deeply(
    [ sort { $a->name cmp $b->name } Class::MOP::get_all_metaclass_instances ],
    [ 
        Class::MOP::Attribute->meta, 
        Class::MOP::Class->meta, 
        $CLASS_MOP_CLASS_IMMUTABLE_CLASS->meta,         
        Class::MOP::Instance->meta,         
        Class::MOP::Method->meta,
        Class::MOP::Method::Accessor->meta,
        Class::MOP::Method::Constructor->meta,                        
        Class::MOP::Method::Generated->meta,        
        Class::MOP::Method::Wrapped->meta,
        Class::MOP::Module->meta, 
        Class::MOP::Object->meta,          
        Class::MOP::Package->meta,             
    ],
    '... got all the metaclass instances');

is_deeply(
    [ sort { $a cmp $b } Class::MOP::get_all_metaclass_names() ],
    [ sort qw/
        Class::MOP::Attribute      
        Class::MOP::Class
        Class::MOP::Instance
        Class::MOP::Method
        Class::MOP::Method::Accessor 
        Class::MOP::Method::Constructor   
        Class::MOP::Method::Generated             
        Class::MOP::Method::Wrapped
        Class::MOP::Module  
        Class::MOP::Object        
        Class::MOP::Package                      
    /,  $CLASS_MOP_CLASS_IMMUTABLE_CLASS  ],
    '... got all the metaclass names');
    
is_deeply(
    [ map { $_->meta->identifier } sort { $a cmp $b } Class::MOP::get_all_metaclass_names() ],
    [ 
       "Class::MOP::Attribute-"           . $Class::MOP::Attribute::VERSION           . "-cpan:STEVAN",  
       "Class::MOP::Class-"               . $Class::MOP::Class::VERSION               . "-cpan:STEVAN",
       $CLASS_MOP_CLASS_IMMUTABLE_CLASS,
       "Class::MOP::Instance-"            . $Class::MOP::Instance::VERSION            . "-cpan:STEVAN",
       "Class::MOP::Method-"              . $Class::MOP::Method::VERSION              . "-cpan:STEVAN",
       "Class::MOP::Method::Accessor-"    . $Class::MOP::Method::Accessor::VERSION    . "-cpan:STEVAN",                 
       "Class::MOP::Method::Constructor-" . $Class::MOP::Method::Constructor::VERSION . "-cpan:STEVAN",
       "Class::MOP::Method::Generated-"   . $Class::MOP::Method::Generated::VERSION   . "-cpan:STEVAN",                        
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



