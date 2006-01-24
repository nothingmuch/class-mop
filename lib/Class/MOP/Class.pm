
package Class::MOP::Class;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype';
use Sub::Name    'subname';
use B            'svref_2object';

our $VERSION = '0.01';

# Creation

sub initialize {
    my ($class, $package_name) = @_;
    (defined $package_name)
        || confess "You must pass a package name";
    bless \$package_name => $class;
}

sub create {
    my ($class, $package_name, $package_version, %options) = @_;
    (defined $package_name)
        || confess "You must pass a package name";
    my $code = "package $package_name;";
    $code .= "\$$package_name\:\:VERSION = '$package_version';" 
        if defined $package_version;
    eval $code;
    confess "creation of $package_name failed : $@" if $@;    
    my $meta = $package_name->meta;
    $meta->superclasses(@{$options{superclasses}})
        if exists $options{superclasses};
    # ... rest to come later ...
    return $meta;
}

# Informational 

sub name { ${$_[0]} }

sub version {  
    my $self = shift;
    no strict 'refs';
    ${$self->name . '::VERSION'};
}

# Inheritance

sub superclasses {
    my $self = shift;
    no strict 'refs';
    if (@_) {
        my @supers = @_;
        @{$self->name . '::ISA'} = @supers;
    }
    @{$self->name . '::ISA'};        
}

sub class_precedence_list {
    my $self = shift;
    (
        $self->name, 
        map { 
            $_->meta->class_precedence_list()
        } $self->superclasses()
    );   
}

## Methods

sub add_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";
    (reftype($method) && reftype($method) eq 'CODE')
        || confess "Your code block must be a CODE reference";
    my $full_method_name = ($self->name . '::' . $method_name);    
        
    no strict 'refs';
    *{$full_method_name} = subname $full_method_name => $method;
}

sub has_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";    
    
    my $sub_name = ($self->name . '::' . $method_name);    
        
    no strict 'refs';
    return 0 unless defined &{$sub_name};        
    return 0 unless _find_subroutine_package(\&{$sub_name}) eq $self->name;
    return 1;
}

sub get_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    no strict 'refs';    
    return \&{$self->name . '::' . $method_name} 
        if $self->has_method($method_name);    
}

## Private Utility Methods

# initially borrowed from Class::Trait 0.20 - Thanks Ovid :)
# later re-worked to support subs named with Sub::Name
sub _find_subroutine_package {
    my $sub     = shift;
    my $package = eval { svref_2object($sub)->GV->STASH->NAME };
    confess "Could not determine calling package: $@" if $@;
    return $package;
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Class - Class Meta Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Stevan Little E<gt>stevan@iinteractive.comE<lt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut