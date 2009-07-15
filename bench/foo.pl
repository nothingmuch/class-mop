#!perl
# a moose using script for profiling
# Usage: perl bench/profile.pl

package Foo;
use Moose;

has aaa => (
	is => 'rw',
	isa => 'Str',
);

has bbb => (
	is => 'rw',
	isa => 'Str',
);

has ccc => (
	is => 'rw',
	isa => 'Str',
);

has ddd => (
	is => 'rw',
	isa => 'Str',
);

has eee => (
	is => 'rw',
	isa => 'Str',
);

__PACKAGE__->meta->make_immutable();


package Bar;
use Moose;

extends 'Foo';

has xaaa => (
	is => 'rw',
	isa => 'Str',
);

has xbbb => (
	is => 'rw',
	isa => 'Str',
);

has xccc => (
	is => 'rw',
	isa => 'Str',
);

has xddd => (
	is => 'rw',
	isa => 'Str',
);

has xeee => (
	is => 'rw',
	isa => 'Str',
);

__PACKAGE__->meta->make_immutable();
