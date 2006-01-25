
package Class::MOP::Class;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype';
use Sub::Name    'subname';
use B            'svref_2object';

our $VERSION = '0.01';

# Creation

{
    # Metaclasses are singletons, so we cache them here.
    # there is no need to worry about destruction though
    # because they should die only when the program dies.
    # After all, do package definitions even get reaped?
    my %METAS;
    sub initialize {
        my ($class, $package_name) = @_;
        (defined $package_name && $package_name)
            || confess "You must pass a package name";
        $METAS{$package_name} ||= bless \$package_name => blessed($class) || $class;
    }
}

sub create {
    my ($class, $package_name, $package_version, %options) = @_;
    (defined $package_name && $package_name)
        || confess "You must pass a package name";
    my $code = "package $package_name;";
    $code .= "\$$package_name\:\:VERSION = '$package_version';" 
        if defined $package_version;
    eval $code;
    confess "creation of $package_name failed : $@" if $@;    
    my $meta = $class->initialize($package_name);
    $meta->superclasses(@{$options{superclasses}})
        if exists $options{superclasses};
    if (exists $options{methods}) {
        foreach my $method_name (keys %{$options{methods}}) {
            $meta->add_method($method_name, $options{methods}->{$method_name});
        }
    }
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
    # NOTE:
    # We need to check for ciruclar inheirtance here.
    # This will do nothing if all is well, and blow
    # up otherwise. Yes, it's an ugly hack, better 
    # suggestions are welcome.
    { $self->name->isa('This is a test for circular inheritance') }
    # ... and no back to our regularly scheduled program
    (
        $self->name, 
        map { 
            $self->initialize($_)->class_precedence_list()
        } $self->superclasses()
    );   
}

## Methods

sub add_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";
    # use reftype here to allow for blessed subs ...
    (reftype($method) && reftype($method) eq 'CODE')
        || confess "Your code block must be a CODE reference";
    my $full_method_name = ($self->name . '::' . $method_name);    
        
    no strict 'refs';
    no warnings 'redefine';
    *{$full_method_name} = subname $full_method_name => $method;
}

{

    ## private utility functions for has_method
    my $_find_subroutine_package_name = sub { eval { svref_2object($_[0])->GV->STASH->NAME } };
    my $_find_subroutine_name         = sub { eval { svref_2object($_[0])->GV->NAME        } };

    sub has_method {
        my ($self, $method_name) = @_;
        (defined $method_name && $method_name)
            || confess "You must define a method name";    
    
        my $sub_name = ($self->name . '::' . $method_name);    
        
        no strict 'refs';
        return 0 if !defined(&{$sub_name});        
        return 0 if $_find_subroutine_package_name->(\&{$sub_name}) ne $self->name &&
                    $_find_subroutine_name->(\&{$sub_name})         ne '__ANON__';
        return 1;
    }

}

sub get_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    no strict 'refs';    
    return \&{$self->name . '::' . $method_name} 
        if $self->has_method($method_name);   
    return; # <- make sure to return undef
}

sub remove_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";
    
    my $removed_method = $self->get_method($method_name);    
    
    no strict 'refs';
    delete ${$self->name . '::'}{$method_name}
        if defined $removed_method;
        
    return $removed_method;
}

sub get_method_list {
    my $self = shift;
    no strict 'refs';
    grep { $self->has_method($_) } %{$self->name . '::'};
}

sub compute_all_applicable_methods {
    my $self = shift;
    my @methods;
    # keep a record of what we have seen
    # here, this will handle all the 
    # inheritence issues because we are 
    # using the &class_precedence_list
    my (%seen_class, %seen_method);
    foreach my $class ($self->class_precedence_list()) {
        next if $seen_class{$class};
        $seen_class{$class}++;
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        foreach my $method_name ($meta->get_method_list()) { 
            next if exists $seen_method{$method_name};
            $seen_method{$method_name}++;
            push @methods => {
                name  => $method_name, 
                class => $class,
                code  => $meta->get_method($method_name)
            };
        }
    }
    return @methods;
}

## Recursive Version of compute_all_applicable_methods
# sub compute_all_applicable_methods {
#     my ($self, $seen) = @_;
#     $seen ||= {};
#     (
#         (map { 
#             if (exists $seen->{$_}) { 
#                 ();
#             }
#             else {
#                 $seen->{$_}++;
#                 {
#                     name  => $_, 
#                     class => $self->name,
#                     code  => $self->get_method($_)
#                 };
#             }
#         } $self->get_method_list()),
#         map { 
#             $self->initialize($_)->compute_all_applicable_methods($seen)
#         } $self->superclasses()
#     );
# }

sub find_all_methods_by_name {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name to find";    
    my @methods;
    # keep a record of what we have seen
    # here, this will handle all the 
    # inheritence issues because we are 
    # using the &class_precedence_list
    my %seen_class;
    foreach my $class ($self->class_precedence_list()) {
        next if $seen_class{$class};
        $seen_class{$class}++;
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        push @methods => {
            name  => $method_name, 
            class => $class,
            code  => $meta->get_method($method_name)
        } if $meta->has_method($method_name);
    }
    return @methods;

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