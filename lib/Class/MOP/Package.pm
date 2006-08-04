
package Class::MOP::Package;

use strict;
use warnings;

use Scalar::Util 'blessed';
use Carp         'confess';

our $VERSION = '0.02';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

# creation ...

sub initialize {
    my $class        = shift;
    my $package_name = shift;
    # we hand-construct the class 
    # until we can bootstrap it
    no strict 'refs';
    return bless { 
        '$:package'   => $package_name,
        '%:namespace' => \%{$package_name . '::'},
    } => $class;
}

# Attributes

# NOTE:
# all these attribute readers will be bootstrapped 
# away in the Class::MOP bootstrap section

sub name      { $_[0]->{'$:package'}   }
sub namespace { $_[0]->{'%:namespace'} }

# utility methods

{
    my %SIGIL_MAP = (
        '$' => 'SCALAR',
        '@' => 'ARRAY',
        '%' => 'HASH',
        '&' => 'CODE',
    );
    
    sub _deconstruct_variable_name {
        my ($self, $variable) = @_;

        (defined $variable)
            || confess "You must pass a variable name";    

        my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 

        (defined $sigil)
            || confess "The variable name must include a sigil";    

        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";    
        
        return ($name, $sigil, $SIGIL_MAP{$sigil});
    }
}

# Class attributes

sub add_package_symbol {
    my ($self, $variable, $initial_value) = @_;

    my ($name, $sigil, $type) = $self->_deconstruct_variable_name($variable); 

    no strict 'refs';
    no warnings 'misc', 'redefine';
    *{$self->name . '::' . $name} = $initial_value;    
}

sub has_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = $self->_deconstruct_variable_name($variable); 

    return 0 unless exists $self->namespace->{$name};    
    defined *{$self->namespace->{$name}}{$type} ? 1 : 0;
}

sub get_package_symbol {
    my ($self, $variable) = @_;    

    my ($name, $sigil, $type) = $self->_deconstruct_variable_name($variable); 

    return *{$self->namespace->{$name}}{$type}
        if exists $self->namespace->{$name};
    $self->add_package_symbol($variable);
}

sub remove_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = $self->_deconstruct_variable_name($variable); 

    if ($type eq 'SCALAR') {
        undef ${$self->namespace->{$name}};    
    }
    elsif ($type eq 'ARRAY') {
        undef @{$self->namespace->{$name}};    
    }
    elsif ($type eq 'HASH') {
        undef %{$self->namespace->{$name}};    
    }
    elsif ($type eq 'CODE') {
        # FIXME:
        # this is crap, it is probably much 
        # easier to write this in XS.
        my ($scalar, @array, %hash);
        $scalar = ${$self->namespace->{$name}} if defined *{$self->namespace->{$name}}{SCALAR};
        @array  = @{$self->namespace->{$name}} if defined *{$self->namespace->{$name}}{ARRAY};
        %hash   = %{$self->namespace->{$name}} if defined *{$self->namespace->{$name}}{HASH};
        {
            no strict 'refs';
            delete ${$self->name . '::'}{$name};
        }
        ${$self->namespace->{$name}} = $scalar if defined $scalar;
        @{$self->namespace->{$name}} = @array  if scalar  @array;
        %{$self->namespace->{$name}} = %hash   if keys    %hash;            
    }    
    else {
        confess "This should never ever ever happen";
    }
}

sub list_all_package_symbols {
    my ($self) = @_;
    return keys %{$self->namespace};
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Package - Package Meta Object

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<meta>

=item B<initialize>

=item B<name>

=item B<namespace>

=item B<add_package_symbol>

=item B<get_package_symbol>

=item B<has_package_symbol>

=item B<remove_package_symbol>

=item B<list_all_package_symbols>

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

Yuval Kogman E<lt>nothingmuch@woobling.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut