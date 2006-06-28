#!/usr/bin/perl

package Bench::Construct;
use Moose;

has class => (
    isa => "Str",
    is  => "ro",
);

has args => (
    isa => "ArrayRef",
    is  => "ro",
    auto_deref => 1,
);

sub code {
    my $self = shift;

    my $class = $self->class;
    my @args  = $self->args;

    sub { my $obj = $class->new( @args ) }
}

__PACKAGE__;

__END__
