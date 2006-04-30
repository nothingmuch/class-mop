#!/usr/bin/perl

package Class::MOP::Instance::Inlinable;

use strict;
use warnings;

# cheap ass pseudo-mixin

# inlinable operation snippets

sub inline_get_slot_value {
    my ($self, $instance, $slot_name) = @_;
    sprintf "%s->{%s}", $instance, $slot_name;
}

sub inline_set_slot_value {
    my ($self, $instance, $slot_name, $value) = @_;
    $self->_inline_slot_lvalue( $instance, $slot_name ) . " = $value", 
}

sub inline_set_slot_value_with_init { 
    my ($self, $instance, $slot_name, $value) = @_;

    $self->_join_statements( 
        $self->inline_initialize_slot( $instance, $slot_name ),
        $self->inline_set_slot_value( $instance, $slot_name, $value ),
    );
}

sub inline_set_slot_value_weak {
    my ($self, $instance, $slot_name, $value) = @_;

    $self->_join_statements(
        $self->inline_set_slot_value( $instance, $slot_name, $value ),
        $self->inline_weaken_slot_value( $instance, $slot_name ),
    );
}

sub inline_weaken_slot_value {
    my ($self, $instance, $slot_name) = @_;
    sprintf "Scalar::Util::weaken( %s )", $self->_inline_slot_lvalue( $instance, $slot_name );
}

sub inline_initialize_slot {
    return "";
}

sub inline_slot_initialized {
    my ($self, $instance, $slot_name) = @_;
    "exists " . $self->inline_get_slot_value;
}

sub _join_statements {
    my ( $self, @statements ) = @_;
    my @filtered = grep { length } @statements;
    return $filtered[0] if @filtered == 1;
    return join("; ", @filtered);
}

sub _inline_slot_lvalue {
    my ($self, $instance, $slot_name) = @_;
    $self->inline_get_slot_value( $instance, $slot_name );
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Class::MOP::Instance::Inlinable - Generate inline slot operations.

=head1 SYNOPSIS

    # see Moose::Meta::Attribute for an example

=head1 DESCRIPTION

This pseudo-mixin class provides additional methods to work along side
L<Class::MOP::Instance>, which can be used to generate accessors with inlined
slot operations.

=cut


