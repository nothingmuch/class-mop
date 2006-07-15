#!/usr/bin/perl

package Class::MOP::Iterator;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype', 'weaken';

our $VERSION = "0.01";

use base 'Class::MOP::Module';

sub meta {
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

sub new {
    my ( $class, %options ) = @_;

    my @missing;
    for ( qw/generator predicate/ ) {
        push @missing, $_ unless $options{$_}
    }
    die "Missing: @missing" if @missing;

    bless \%options, $class;
}

sub from_list {
    my ( $class, @list ) = @_;
    return $class->new(
        generator => sub { shift @list },
        predicate => sub { scalar(@list) },
    );
}

sub concat {
    my ( $class, @iters ) = @_;

    my $next_iter;
    my $get_next_iter = sub {
        while ( !$next_iter or $next_iter->is_done ) {
            undef $next_iter;
            return unless @iters;
            $next_iter = shift @iters;
        }

        return $next_iter;
    };

    return $class->new(
        predicate => sub { ( $get_next_iter->() || return )->check_predicate },
        generator => sub { ( $get_next_iter->() || return )->next },
    );
}

sub cons {
    my ( $class, $item, $iter ) = @_;
    
    $class->new(
        predicate => sub { 1 },
        generator => sub {
            my $self = shift;

            # replace the current iter stuff for the next value
            $self->predicate( $iter->predicate );
            $self->generator( $iter->generator );

            return $item;
        },
    );
}

sub map {
    my ( $class, $map, @iters ) = @_;

    my $caller = join(" ", (caller)[0 .. 2]);

    my $iter = ( ( @iters == 1 ) ? $iters[0] : $class->concat(@iters) );

    return $class->new(
        predicate => sub { $iter->check_predicate },
        generator => sub {
            if ( $iter->check_predicate ) {
                my $next = $iter->next;
                local $_ = $next;
                return $map->($next);
            } else {
                return;
            }
        },
    );
}

sub grep {
    my ( $class, $filter, @iters ) = @_;
    
    my $iter = ( ( @iters == 1 ) ? $iters[0] : $class->concat(@iters) );

    my $have_next; # always know if there's a next match for predicate
    my $next_value; # if we had to look ahead, this is where we keep it

    my $filter_next = sub {
        if ( !$have_next ) {
            until ( $iter->is_done ) {
                my $next = $iter->next;

                local $_ = $next;
                if ( $filter->( $next ) ) {
                    $have_next = 1;
                    return $next_value = $next;
                }
            }
        }
    };

    return $class->new(
        predicate => sub {
            $filter_next->() unless $have_next;
            return $have_next;
        },
        generator => sub {
            $filter_next->() unless $have_next;
            if ( $have_next ) {
                $have_next = 0;
                return $next_value;
            } else {
                return;
            }
        },
    );
}

sub flatten {
    my ( $class, @iters ) = @_;

    my $iter_of_iters = ( ( @iters == 1 ) ? $iters[0] : $class->concat(@iters) );

    my $next_iter;
    my $get_next_iter = sub {
        while ( !$next_iter or $next_iter->is_done ) {
            undef $next_iter;
            return if $iter_of_iters->is_done;
            $next_iter = $iter_of_iters->next;
        }

        return $next_iter;
    };

    $class->new(
        predicate => sub { ( $get_next_iter->() || return )->check_predicate },
        generator => sub { ( $get_next_iter->() || return )->next },
    );
}

sub predicate {
    my $self = shift;
    $self->{predicate} = shift if @_;
    $self->{predicate};
}

sub generator {
    my $self = shift;
    $self->{generator} = shift if @_;
    $self->{generator};
}

sub check_predicate {
    my $self = shift;

    my $pred = $self->predicate;
    return $self->$pred(@_);
}

sub is_done {
    my $self = shift;
    not($self->check_predicate);
}

sub next {
    my $self = shift;
    
    my $gen = $self->generator;
    $self->$gen(@_);
}

sub all {
    my $self = shift;

    my @ret;
    push @ret, $self->next until $self->is_done;

    return @ret;
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Class::MOP::Iterator - Composable iterators for Class::MOP return values.

=head1 SYNOPSIS

	use Class::MOP::Iterator;

=head1 DESCRIPTION

These are not the loveliest iterators since they are not purely functional.

That ought to be fixed, but note that the predicate/generator are invoked as
methods so that they may replace theselves.

A nice alternative would be for someone to write L<Inline::GHC>.

=head1 METHODS

=head2 Constructors

=over 4

=item new %options

Takes an options hash which must contain the fields C<generator> and
C<predicate>.

C<generator> must return the next item in the iterator, and C<predicate> must
return true if there are any items remaining.

Both code refs accept the iterator as the invocant, and may invoke methods on
it.

=item concat @iters

This is a bit like saying C<< map { @$_ } @array_of_arrays >>. It returns an
iterator that will return all the values from all it's sub iterators.

=item cons $item, $iter

Creates an iterator that will first return $item, and then every element in
$iter.

=item grep $filter, @iters

Creates an iterator over all the iterms that for which C<< $filter->($item) >>
returns true.

The item is both in C<$_> and in C<$_[0]> for C<$filter>.

=item map $sub, @iters

Creates an iterator of consisting of C<< $sub->( $item ) >> for every item in
C<@iters>.

The item is both in C<$_> and in C<$_[0]> for C<$sub>.

=item from_list @list

Creates an iterator from a list of items.

Every item will be returned, akin to calling C<shift> repeatedly.

=item flatten @iters_of_iters

Accepts iterators whose items are themselves iterators, and flattens the
output.

=back

=head2 Instance methods

=over 4

=item next

Return the next item in the iterator.

=item all

Deplete the iterator, returning all the items.

=item is_done

Returns whether or not the iterator is depleted.

=item check_predicate

The inverse of is_done.

=item generator

Set or get the generator code ref.

=item predicate

Set or get the predicate code ref.

=back

=head2 Introspection

=over 4

=item meta

Returns the L<Class::MOP::Class> instance which is related with the class of
the invocant.

=back

=cut


