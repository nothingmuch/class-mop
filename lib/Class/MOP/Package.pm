
package Class::MOP::Package;

use strict;
use warnings;

use Scalar::Util 'blessed';
use Carp         'confess';

our $VERSION = '0.01';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

# creation ...

sub initialize {
    my ($class, $package) = @_;
    bless { '$:package' => $package } => $class;
}

# Attributes

# NOTE:
# all these attribute readers will be bootstrapped 
# away in the Class::MOP bootstrap section

sub name { $_[0]->{'$:package'} }

# Class attributes

{
    my %SIGIL_MAP = (
        '$' => 'SCALAR',
        '@' => 'ARRAY',
        '%' => 'HASH',
        '&' => 'CODE',
    );

    sub add_package_symbol {
        my ($self, $variable, $initial_value) = @_;
    
        (defined $variable)
            || confess "You must pass a variable name";    
    
        my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    
        (defined $sigil)
            || confess "The variable name must include a sigil";    
    
        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";
    
        no strict 'refs';
        no warnings 'misc';
        *{$self->name . '::' . $name} = $initial_value;    
    }

    sub has_package_symbol {
        my ($self, $variable) = @_;
        (defined $variable)
            || confess "You must pass a variable name";

        my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    
        (defined $sigil)
            || confess "The variable name must include a sigil";    
    
        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";
    
        no strict 'refs';
        defined *{$self->name . '::' . $name}{$SIGIL_MAP{$sigil}} ? 1 : 0;
    
    }

    sub get_package_symbol {
        my ($self, $variable) = @_;    
        (defined $variable)
            || confess "You must pass a variable name";
    
        my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    
        (defined $sigil)
            || confess "The variable name must include a sigil";    
    
        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";
    
        no strict 'refs';
        return *{$self->name . '::' . $name}{$SIGIL_MAP{$sigil}};

    }

    sub remove_package_symbol {
        my ($self, $variable) = @_;
    
        (defined $variable)
            || confess "You must pass a variable name";
        
        my ($sigil, $name) = ($variable =~ /^(.)(.*)$/); 
    
        (defined $sigil)
            || confess "The variable name must include a sigil";    
    
        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'"; 
    
        no strict 'refs';
        if ($SIGIL_MAP{$sigil} eq 'SCALAR') {
            undef ${$self->name . '::' . $name};    
        }
        elsif ($SIGIL_MAP{$sigil} eq 'ARRAY') {
            undef @{$self->name . '::' . $name};    
        }
        elsif ($SIGIL_MAP{$sigil} eq 'HASH') {
            undef %{$self->name . '::' . $name};    
        }
        elsif ($SIGIL_MAP{$sigil} eq 'CODE') {
            undef &{$self->name . '::' . $name};    
        }    
        else {
            confess "This should never ever ever happen";
        }
    }

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

=item B<add_package_symbol>

=item B<get_package_symbol>

=item B<has_package_symbol>

=item B<remove_package_symbol>

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut