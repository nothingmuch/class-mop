
package Class::MOP::Class;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';
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

## Private Utility Methods

# borrowed from Class::Trait 0.20 - Thanks Ovid :)
sub _find_subroutine_package {
    my $sub     = shift;
    my $package = '';
    eval {
        my $stash = svref_2object($sub)->STASH;
        $package = $stash->NAME 
            if $stash && $stash->can('NAME');
    };
    confess "Could not determine calling package: $@" 
        if $@;
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