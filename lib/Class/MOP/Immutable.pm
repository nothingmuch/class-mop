
package Class::MOP::Immutable;

use strict;
use warnings;

use Class::MOP::Method::Constructor;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.78_01';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

sub new {
    my ($class, @args) = @_;

    my ( $metaclass, $options );

    if ( @args == 2 ) {
        # compatibility args
        ( $metaclass, $options ) = @args;
    } else {
        unshift @args, "metaclass" if @args % 2 == 1;

        # default named args
        my %options = @args;
        $options = \%options;
        $metaclass = $options{metaclass};
    }

    my $self = $class->_new(
        'metaclass'           => $metaclass,
        'options'             => $options,
        'immutable_metaclass' => undef,
        'inlined_constructor' => undef,
    );

    return $self;
}

sub _new {
    my $class = shift;
    my $options = @_ == 1 ? $_[0] : {@_};

    bless $options, $class;
}

sub immutable_metaclass {
    my $self = shift;

    $self->create_immutable_metaclass unless $self->{'immutable_metaclass'};

    return $self->{'immutable_metaclass'};
}

sub metaclass           { (shift)->{'metaclass'}           }
sub options             { (shift)->{'options'}             }
sub inlined_constructor { (shift)->{'inlined_constructor'} }

sub create_immutable_metaclass {
    my $self = shift;

    # NOTE:
    # The immutable version of the
    # metaclass is just a anon-class
    # which shadows the methods
    # appropriately
    $self->{'immutable_metaclass'} = Class::MOP::Class->create_anon_class(
        superclasses => [ blessed($self->metaclass) ],
        methods      => $self->create_methods_for_immutable_metaclass,
    );
}


my %DEFAULT_METHODS = (
    # I don't really understand this, but removing it breaks tests (groditi)
    meta => sub {
        my $self = shift;
        # if it is not blessed, then someone is asking
        # for the meta of Class::MOP::Immutable
        return Class::MOP::Class->initialize($self) unless blessed($self);
        # otherwise, they are asking for the metaclass
        # which has been made immutable, which is itself
        # except in the cases where it is a metaclass itself
        # that has been made immutable and for that we need 
        # to dig a bit ...
        if ($self->isa('Class::MOP::Class')) {
            return $self->{'___original_class'}->meta;
        }
        else {
            return $self;
        }
    },
    is_mutable     => sub { 0  },
    is_immutable   => sub { 1  },
    make_immutable => sub { () },
);

# NOTE:
# this will actually convert the
# existing metaclass to an immutable
# version of itself
sub make_metaclass_immutable {
    my ($self, $metaclass, $options) = @_;

    my %options = (
        inline_accessors   => 1,
        inline_constructor => 1,
        inline_destructor  => 0,
        constructor_name   => 'new',
        debug              => 0,
        %$options,
    );

    %$options = %options; # FIXME who the hell is relying on this?!? tests fail =(

    $self->_inline_accessors( $metaclass, \%options );
    $self->_inline_constructor( $metaclass, \%options );
    $self->_inline_destructor( $metaclass, \%options );
    $self->_check_memoized_methods( $metaclass, \%options );

    $metaclass->{'___original_class'} = blessed($metaclass);
    bless $metaclass => $self->immutable_metaclass->name;
}

sub _inline_accessors {
    my ( $self, $metaclass, $options ) = @_;

    return unless $options->{inline_accessors};

    foreach my $attr_name ( $metaclass->get_attribute_list ) {
        $metaclass->get_attribute($attr_name)->install_accessors(1);
    }
}

sub _inline_constructor {
    my ( $self, $metaclass, $options ) = @_;

    return unless $options->{inline_constructor};

    return
        unless $options->{replace_constructor}
            or !$metaclass->has_method( $options->{constructor_name} );

    my $constructor_class = $options->{constructor_class}
        || 'Class::MOP::Method::Constructor';

    my $constructor = $constructor_class->new(
        options      => $options,
        metaclass    => $metaclass,
        is_inline    => 1,
        package_name => $metaclass->name,
        name         => $options->{constructor_name},
    );

    if ( $options->{replace_constructor} or $constructor->can_be_inlined ) {
        $metaclass->add_method( $options->{constructor_name} => $constructor );
        $self->{inlined_constructor} = $constructor;
    }
}

sub _inline_destructor {
    my ( $self, $metaclass, $options ) = @_;

    return unless $options->{inline_destructor};

    ( exists $options->{destructor_class} )
        || confess "The 'inline_destructor' option is present, but "
        . "no destructor class was specified";

    my $destructor_class = $options->{destructor_class};

    return unless $destructor_class->is_needed($metaclass);

    my $destructor = $destructor_class->new(
        options      => $options,
        metaclass    => $metaclass,
        package_name => $metaclass->name,
        name         => 'DESTROY'
    );

    return unless $destructor->is_needed;

    $metaclass->add_method( 'DESTROY' => $destructor )
}

sub _check_memoized_methods {
    my ( $self, $metaclass, $options ) = @_;

    my $memoized_methods = $self->options->{memoize};
    foreach my $method_name ( keys %{$memoized_methods} ) {
        my $type = $memoized_methods->{$method_name};

        ( $metaclass->can($method_name) )
            || confess "Could not find the method '$method_name' in "
            . $metaclass->name;
    }
}

sub create_methods_for_immutable_metaclass {
    my $self = shift;

    my %methods   = %DEFAULT_METHODS;
    my $metaclass = $self->metaclass;
    my $meta      = $metaclass->meta;

    $methods{get_mutable_metaclass_name}
        = sub { (shift)->{'___original_class'} };

    $methods{immutable_transformer} = sub {$self};

    return {
        %DEFAULT_METHODS,
        $self->_make_read_only_methods( $metaclass, $meta ),
        $self->_make_uncallable_methods( $metaclass, $meta ),
        $self->_make_memoized_methods( $metaclass, $meta ),
        $self->_make_wrapped_methods( $metaclass, $meta ),
        get_mutable_metaclass_name => sub { (shift)->{'___original_class'} },
        immutable_transformer      => sub {$self},
    };
}

sub _make_read_only_methods {
    my ( $self, $metaclass, $meta ) = @_;

    my %methods;
    foreach my $read_only_method ( @{ $self->options->{read_only} } ) {
        my $method = $meta->find_method_by_name($read_only_method);

        ( defined $method )
            || confess "Could not find the method '$read_only_method' in "
            . $metaclass->name;

        $methods{$read_only_method} = sub {
            confess "This method is read-only" if scalar @_ > 1;
            goto &{ $method->body };
        };
    }

    return %methods;
}

sub _make_uncallable_methods {
    my ( $self, $metaclass, $meta ) = @_;

    my %methods;
    foreach my $cannot_call_method ( @{ $self->options->{cannot_call} } ) {
        $methods{$cannot_call_method} = sub {
            confess
                "This method ($cannot_call_method) cannot be called on an immutable instance";
        };
    }

    return %methods;
}

sub _make_memoized_methods {
    my ( $self, $metaclass, $meta ) = @_;

    my %methods;

    my $memoized_methods = $self->options->{memoize};
    foreach my $method_name ( keys %{$memoized_methods} ) {
        my $type   = $memoized_methods->{$method_name};
        my $key    = '___' . $method_name;
        my $method = $meta->find_method_by_name($method_name);

        if ( $type eq 'ARRAY' ) {
            $methods{$method_name} = sub {
                @{ $_[0]->{$key} } = $method->execute( $_[0] )
                    if !exists $_[0]->{$key};
                return @{ $_[0]->{$key} };
            };
        }
        elsif ( $type eq 'HASH' ) {
            $methods{$method_name} = sub {
                %{ $_[0]->{$key} } = $method->execute( $_[0] )
                    if !exists $_[0]->{$key};
                return %{ $_[0]->{$key} };
            };
        }
        elsif ( $type eq 'SCALAR' ) {
            $methods{$method_name} = sub {
                $_[0]->{$key} = $method->execute( $_[0] )
                    if !exists $_[0]->{$key};
                return $_[0]->{$key};
            };
        }
    }

    return %methods;
}

sub _make_wrapped_methods {
    my ( $self, $metaclass, $meta ) = @_;

    my %methods;

    my $wrapped_methods = $self->options->{wrapped};

    foreach my $method_name ( keys %{$wrapped_methods} ) {
        my $method = $meta->find_method_by_name($method_name);

        ( defined $method )
            || confess "Could not find the method '$method_name' in "
            . $metaclass->name;

        my $wrapper = $wrapped_methods->{$method_name};

        $methods{$method_name} = sub { $wrapper->( $method, @_ ) };
    }

    return %methods;
}

sub make_metaclass_mutable {
    my ($self, $immutable, $options) = @_;

    my %options = %$options;

    my $original_class = $immutable->get_mutable_metaclass_name;
    delete $immutable->{'___original_class'} ;
    bless $immutable => $original_class;

    my $memoized_methods = $self->options->{memoize};
    foreach my $method_name (keys %{$memoized_methods}) {
        my $type = $memoized_methods->{$method_name};

        ($immutable->can($method_name))
          || confess "Could not find the method '$method_name' in " . $immutable->name;
        if ($type eq 'SCALAR' || $type eq 'ARRAY' ||  $type eq 'HASH' ) {
            delete $immutable->{'___' . $method_name};
        }
    }

    if ($options{inline_destructor} && $immutable->has_method('DESTROY')) {
        $immutable->remove_method('DESTROY')
          if blessed($immutable->get_method('DESTROY')) eq $options{destructor_class};
    }

    # NOTE:
    # 14:01 <@stevan> nah,. you shouldnt
    # 14:01 <@stevan> they are just inlined
    # 14:01 <@stevan> which is the default in Moose anyway
    # 14:02 <@stevan> and adding new attributes will just DWIM
    # 14:02 <@stevan> and you really cant change an attribute anyway
    # if ($options{inline_accessors}) {
    #     foreach my $attr_name ($immutable->get_attribute_list) {
    #         my $attr = $immutable->get_attribute($attr_name);
    #         $attr->remove_accessors;
    #         $attr->install_accessors(0);
    #     }
    # }

    # 14:26 <@stevan> the only user of ::Method::Constructor is immutable
    # 14:27 <@stevan> if someone uses it outside of immutable,.. they are either: mst or groditi
    # 14:27 <@stevan> so I am not worried
    if ($options{inline_constructor}  && $immutable->has_method($options{constructor_name})) {
        my $constructor_class = $options{constructor_class} || 'Class::MOP::Method::Constructor';

        if ( blessed($immutable->get_method($options{constructor_name})) eq $constructor_class ) {
            $immutable->remove_method( $options{constructor_name}  );
            $self->{inlined_constructor} = undef;
        }
    }
}

1;

__END__

=pod

=head1 NAME

Class::MOP::Immutable - A class to transform Class::MOP::Class metaclasses

=head1 SYNOPSIS

    use Class::MOP::Immutable;

    my $immutable_metaclass = Class::MOP::Immutable->new($metaclass, {
        read_only   => [qw/superclasses/],
        cannot_call => [qw/
            add_method
            alias_method
            remove_method
            add_attribute
            remove_attribute
            add_package_symbol
            remove_package_symbol
        /],
        memoize     => {
            class_precedence_list             => 'ARRAY',
            compute_all_applicable_attributes => 'ARRAY',
            get_meta_instance                 => 'SCALAR',
            get_method_map                    => 'SCALAR',
        }
    });

    $immutable_metaclass->make_metaclass_immutable(@_)

=head1 DESCRIPTION

This class encapsulates the logic behind immutabilization.

This class provides generic immutabilization logic. Decisions about
I<what> gets transformed are up to the caller.

Immutabilization allows for a number of transformations. It can ask
the calling metaclass to inline methods such as the constructor,
destructor, or accessors. It can memoize metaclass accessors
themselves. It can also turn read-write accessors in the metaclass
into read-only methods, and make attempting to set these values an
error. Finally, it can make some methods throw an exception when they
are called. This is used to disable methods that can alter the class.

=head1 METHODS

=over 4

=item B<< Class::MOP::Immutable->new($metaclass, %options) >>

This method takes a metaclass object (typically a L<Class::MOP::Class>
object) and a hash of options.

It returns a new transformer, but does not actually do any
transforming yet.

This method accepts the following options:

=over 8

=item * inline_accessors

=item * inline_constructor

=item * inline_destructor

These are all booleans indicating whether the specified method(s)
should be inlined.

By default, accessors and the constructor are inlined, but not the
destructor.

=item * replace_constructor

This is a boolean indicating whether an existing constructor should be
replaced when inlining a constructor. This defaults to false.

=item * constructor_name

This is the constructor method name. This defaults to "new".

=item * constructor_class

The name of the method metaclass for constructors. It will be used to
generate the inlined constructor. This defaults to
"Class::MOP::Method::Constructor".

=item * destructor_class

The name of the method metaclass for destructors. It will be used to
generate the inlined destructor. This defaults to
"Class::MOP::Method::Denstructor".

=item * memoize

This option takes a hash reference. They keys are method names to be
memoized, and the values are the type of data the method returns. This
can be one of "SCALAR", "ARRAY", or "HASH".

=item * read_only

This option takes an array reference of read-write methods which will
be made read-only. After they are transformed, attempting to set them
will throw an error.

=item * cannot_call

This option takes an array reference of methods which cannot be called
after immutabilization. Attempting to call these methods will throw an
error.

=item * wrapped

This option takes a hash reference. The keys are method names and the
body is a subroutine reference which will wrap the named method. This
allows you to do some sort of custom transformation to a method.

=back

=item B<< $transformer->options >>

Returns a hash reference of the options passed to C<new>.

=item B<< $transformer->metaclass >>

Returns the metaclass object passed to C<new>.

=item B<< $transformer->immutable_metaclass >>

Returns the immutable metaclass object that is created by the
transformation process.

=item B<< $transformer->inlined_constructor >>

If the constructor was inlined, this returns the constructor method
object that was created to do this.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
