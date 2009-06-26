
package Class::MOP::Method::Clearer;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken';

our $VERSION   = '0.88';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method::Attribute';

sub _initialize_body {
    my $self = shift;

    my $method_name = join "_" => (
        '_generate',
        'method',
        ($self->is_inline ? 'inline' : ())
    );

    $self->{'body'} = $self->$method_name();
}

## generators

sub generate_method {
    Carp::cluck('The generate_clearer_method method has been made private.'
        . " The public version is deprecated and will be removed in a future release.\n");
    shift->_generate_method;
}

sub _generate_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        $attr->clear_value($_[0])
    };
}

## Inline methods

sub generate_method_inline {
    Carp::cluck('The generate_clearer_method_inline method has been made private.'
        . " The public version is deprecated and will be removed in a future release.\n");
    shift->_generate_method_inline;
}

sub _generate_method_inline {
    my $self          = shift;
    my $attr          = $self->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my ( $code, $e ) = $self->_eval_closure(
        {},
        'sub {'
        . $meta_instance->inline_deinitialize_slot('$_[0]', $attr_name)
        . '}'
    );
    confess "Could not generate inline clearer because : $e" if $e;

    return $code;
}

1;

# XXX - UPDATE DOCS
__END__

=pod

=head1 NAME

Class::MOP::Method::Clearer - Method Meta Object for accessors

=head1 SYNOPSIS

    use Class::MOP::Method::Accessor;

    my $reader = Class::MOP::Method::Accessor->new(
        attribute     => $attribute,
        is_inline     => 1,
        accessor_type => 'reader',
    );

    $reader->body->execute($instance); # call the reader method

=head1 DESCRIPTION

This is a subclass of <Class::MOP::Method> which is used by
C<Class::MOP::Attribute> to generate accessor code. It handles
generation of readers, writers, predicates and clearers. For each type
of method, it can either create a subroutine reference, or actually
inline code by generating a string and C<eval>'ing it.

=head1 METHODS

=over 4

=item B<< Class::MOP::Method::Accessor->new(%options) >>

This returns a new C<Class::MOP::Method::Accessor> based on the
C<%options> provided.

=over 4

=item * attribute

This is the C<Class::MOP::Attribute> for which accessors are being
generated. This option is required.

=item * accessor_type

This is a string which should be one of "reader", "writer",
"accessor", "predicate", or "clearer". This is the type of method
being generated. This option is required.

=item * is_inline

This indicates whether or not the accessor should be inlined. This
defaults to false.

=item * name

The method name (without a package name). This is required.

=item * package_name

The package name for the method. This is required.

=back

=item B<< $metamethod->accessor_type >>

Returns the accessor type which was passed to C<new>.

=item B<< $metamethod->is_inline >>

Returns a boolean indicating whether or not the accessor is inlined.

=item B<< $metamethod->associated_attribute >>

This returns the L<Class::MOP::Attribute> object which was passed to
C<new>.

=item B<< $metamethod->body >>

The method itself is I<generated> when the accessor object is
constructed.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

