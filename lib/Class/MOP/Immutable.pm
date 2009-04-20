
package Class::MOP::Immutable;

use strict;
use warnings;

use Class::MOP::Method::Constructor;

use Carp         'confess';
use Scalar::Util 'blessed';

our $VERSION   = '0.82';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

sub new {
    my ($class, @args) = @_;

    unshift @args, 'metaclass' if @args % 2 == 1;

    my %options = (
        inline_accessors   => 1,
        inline_constructor => 1,
        inline_destructor  => 0,
        constructor_name   => 'new',
        constructor_class  => 'Class::MOP::Method::Constructor',
        debug              => 0,
        @args,
    );

    my $self = $class->_new(
        'metaclass'           => delete $options{metaclass},
        'options'             => \%options,
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

    return $self->{'immutable_metaclass'} ||= $self->_create_immutable_metaclass;
}

sub metaclass           { (shift)->{'metaclass'}           }
sub options             { (shift)->{'options'}             }
sub inlined_constructor { (shift)->{'inlined_constructor'} }

sub _create_immutable_metaclass {
    my $self = shift;

    # NOTE: The immutable version of the metaclass is just a
    # anon-class which shadows the methods appropriately
    return Class::MOP::Class->create_anon_class(
        superclasses => [ blessed($self->metaclass) ],
        methods      => $self->_create_methods_for_immutable_metaclass,
    );
}

sub make_metaclass_immutable {
    my $self = shift;

    $self->_inline_accessors;
    $self->_inline_constructor;
    $self->_inline_destructor;
    $self->_check_memoized_methods;

    my $metaclass = $self->metaclass;

    $metaclass->{'___original_class'} = blessed($metaclass);
    bless $metaclass => $self->immutable_metaclass->name;
}

sub _inline_accessors {
    my $self = shift;

    return unless $self->options->{inline_accessors};

    foreach my $attr_name ( $self->metaclass->get_attribute_list ) {
        $self->metaclass->get_attribute($attr_name)->install_accessors(1);
    }
}

sub _inline_constructor {
    my $self = shift;

    return unless $self->options->{inline_constructor};

    unless ($self->options->{replace_constructor}
         or !$self->metaclass->has_method(
             $self->options->{constructor_name}
         )) {
        my $class = $self->metaclass->name;
        warn "Not inlining a constructor for $class since it defines"
           . " its own constructor.\n"
           . "If you are certain you don't need to inline your"
           . " constructor, specify inline_constructor => 0 in your"
           . " call to $class->meta->make_immutable\n";
        return;
    }

    my $constructor_class = $self->options->{constructor_class};

    my $constructor = $constructor_class->new(
        options      => $self->options,
        metaclass    => $self->metaclass,
        is_inline    => 1,
        package_name => $self->metaclass->name,
        name         => $self->options->{constructor_name},
    );

    if (   $self->options->{replace_constructor}
        or $constructor->can_be_inlined ) {
        $self->metaclass->add_method(
            $self->options->{constructor_name} => $constructor );
        $self->{inlined_constructor} = $constructor;
    }
}

sub _inline_destructor {
    my $self = shift;

    return unless $self->options->{inline_destructor};

    ( exists $self->options->{destructor_class} )
        || confess "The 'inline_destructor' option is present, but "
        . "no destructor class was specified";

    my $destructor_class = $self->options->{destructor_class};

    return unless $destructor_class->is_needed( $self->metaclass );

    my $destructor = $destructor_class->new(
        options      => $self->options,
        metaclass    => $self->metaclass,
        package_name => $self->metaclass->name,
        name         => 'DESTROY'
    );

    $self->metaclass->add_method( 'DESTROY' => $destructor );
}

sub _check_memoized_methods {
    my $self = shift;

    my $memoized_methods = $self->options->{memoize};
    foreach my $method_name ( keys %{$memoized_methods} ) {
        my $type = $memoized_methods->{$method_name};

        ( $self->metaclass->can($method_name) )
            || confess "Could not find the method '$method_name' in "
            . $self->metaclass->name;
    }
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
            return Class::MOP::class_of($self->{'___original_class'});
        }
        else {
            return $self;
        }
    },
    is_mutable     => sub { 0  },
    is_immutable   => sub { 1  },
    make_immutable => sub { () },
);

sub _create_methods_for_immutable_metaclass {
    my $self = shift;

    my $metaclass = $self->metaclass;
    my $meta      = Class::MOP::class_of($metaclass);

    return {
        %DEFAULT_METHODS,
        $self->_make_read_only_methods,
        $self->_make_uncallable_methods,
        $self->_make_memoized_methods,
        $self->_make_wrapped_methods,
        get_mutable_metaclass_name => sub { (shift)->{'___original_class'} },
        immutable_transformer      => sub {$self},
    };
}

sub _make_read_only_methods {
    my $self = shift;

    my $metameta = Class::MOP::class_of($self->metaclass);

    my %methods;
    foreach my $read_only_method ( @{ $self->options->{read_only} } ) {
        my $method = $metameta->find_method_by_name($read_only_method);

        ( defined $method )
            || confess "Could not find the method '$read_only_method' in "
            . $self->metaclass->name;

        $methods{$read_only_method} = sub {
            confess "This method is read-only" if scalar @_ > 1;
            goto &{ $method->body };
        };
    }

    return %methods;
}

sub _make_uncallable_methods {
    my $self = shift;

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
    my $self = shift;

    my %methods;

    my $metameta = Class::MOP::class_of($self->metaclass);

    my $memoized_methods = $self->options->{memoize};
    foreach my $method_name ( keys %{$memoized_methods} ) {
        my $type   = $memoized_methods->{$method_name};
        my $key    = '___' . $method_name;
        my $method = $metameta->find_method_by_name($method_name);

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
    my $self = shift;

    my %methods;

    my $wrapped_methods = $self->options->{wrapped};

    my $metameta = Class::MOP::class_of($self->metaclass);

    foreach my $method_name ( keys %{$wrapped_methods} ) {
        my $method = $metameta->find_method_by_name($method_name);

        ( defined $method )
            || confess "Could not find the method '$method_name' in "
            . $self->metaclass->name;

        my $wrapper = $wrapped_methods->{$method_name};

        $methods{$method_name} = sub { $wrapper->( $method, @_ ) };
    }

    return %methods;
}

sub make_metaclass_mutable {
    my $self = shift;

    my $metaclass = $self->metaclass;

    my $original_class = $metaclass->get_mutable_metaclass_name;
    delete $metaclass->{'___original_class'};
    bless $metaclass => $original_class;

    my $memoized_methods = $self->options->{memoize};
    foreach my $method_name ( keys %{$memoized_methods} ) {
        my $type = $memoized_methods->{$method_name};

        ( $metaclass->can($method_name) )
            || confess "Could not find the method '$method_name' in "
            . $metaclass->name;
        if ( $type eq 'SCALAR' || $type eq 'ARRAY' || $type eq 'HASH' ) {
            delete $metaclass->{ '___' . $method_name };
        }
    }

    if (   $self->options->{inline_destructor}
        && $metaclass->has_method('DESTROY') ) {
        $metaclass->remove_method('DESTROY')
            if blessed( $metaclass->get_method('DESTROY') ) eq
                $self->options->{destructor_class};
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
    if (   $self->options->{inline_constructor}
        && $metaclass->has_method( $self->options->{constructor_name} ) ) {
        my $constructor_class = $self->options->{constructor_class}
            || 'Class::MOP::Method::Constructor';

        if (
            blessed(
                $metaclass->get_method( $self->options->{constructor_name} )
            ) eq $constructor_class
            ) {
            $metaclass->remove_method( $self->options->{constructor_name} );
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
            class_precedence_list => 'ARRAY',
            get_all_attributes    => 'ARRAY',
            get_meta_instance     => 'SCALAR',
            get_method_map        => 'SCALAR',
        }
    });

    $immutable_metaclass->make_metaclass_immutable;

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

=item B<< $transformer->make_metaclass_immutable >>

Makes the transformer's metaclass immutable.

=item B<< $transformer->make_metaclass_mutable >>

Makes the transformer's metaclass mutable.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
