#!/usr/bin/perl

package Class::MOP::Iterator;

use strict;
use warnings;

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
        __list => \@list,
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
            unless ( $iter->is_done ) {
                my $next = $iter->next;
                local $_ = $next;
                return $map->($next);
            }

            return
        },
    );
}

sub grep {
    my ( $class, $filter, @iters ) = @_;
    
    my $iter = ( ( @iters == 1 ) ? $iters[0] : $class->concat(@iters) );

    use Data::Dumper;
    $Data::Dumper::Deparse = 1;
    #warn "got iter to filter: ". Dumper($iter, $filter);

    die Carp::longmess unless $iter->isa(__PACKAGE__);

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

=cut


