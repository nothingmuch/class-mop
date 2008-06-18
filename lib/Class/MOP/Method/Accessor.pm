
package Class::MOP::Method::Accessor;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken';

our $VERSION   = '0.63';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method::Generated';

sub new {
    my $class   = shift;
    my %options = @_;

    (exists $options{attribute})
        || confess "You must supply an attribute to construct with";

    (exists $options{accessor_type})
        || confess "You must supply an accessor_type to construct with";

    (blessed($options{attribute}) && $options{attribute}->isa('Class::MOP::Attribute'))
        || confess "You must supply an attribute which is a 'Class::MOP::Attribute' instance";

    ($options{package_name} && $options{name})
        || confess "You must supply the package_name and name parameters $Class::MOP::Method::UPGRADE_ERROR_TEXT";

    my $self = bless {
        # from our superclass
        '&!body'          => undef,
        '$!package_name' => $options{package_name},
        '$!name'         => $options{name},        
        # specific to this subclass
        '$!attribute'     => $options{attribute},
        '$!is_inline'     => ($options{is_inline} || 0),
        '$!accessor_type' => $options{accessor_type},
    } => $class;

    # we don't want this creating
    # a cycle in the code, if not
    # needed
    weaken($self->{'$!attribute'});

    $self->initialize_body;

    return $self;
}

## accessors

sub associated_attribute { (shift)->{'$!attribute'}     }
sub accessor_type        { (shift)->{'$!accessor_type'} }

## factory

sub initialize_body {
    my $self = shift;

    my $method_name = join "_" => (
        'generate',
        $self->accessor_type,
        'method',
        ($self->is_inline ? 'inline' : ())
    );

    eval { $self->{'&!body'} = $self->$method_name() };
    die $@ if $@;
}

## generators

sub generate_accessor_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        $attr->set_value($_[0], $_[1]) if scalar(@_) == 2;
        $attr->get_value($_[0]);
    };
}

sub generate_reader_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        confess "Cannot assign a value to a read-only accessor" if @_ > 1;
        $attr->get_value($_[0]);
    };
}

sub generate_writer_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        $attr->set_value($_[0], $_[1]);
    };
}

sub generate_predicate_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        $attr->has_value($_[0])
    };
}

sub generate_clearer_method {
    my $attr = (shift)->associated_attribute;
    return sub {
        $attr->clear_value($_[0])
    };
}

## Inline methods


sub generate_accessor_method_inline {
    my $attr          = (shift)->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my $code = eval 'sub {'
        . $meta_instance->inline_set_slot_value('$_[0]', "'$attr_name'", '$_[1]')  . ' if scalar(@_) == 2; '
        . $meta_instance->inline_get_slot_value('$_[0]', "'$attr_name'")
    . '}';
    confess "Could not generate inline accessor because : $@" if $@;

    return $code;
}

sub generate_reader_method_inline {
    my $attr          = (shift)->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my $code = eval 'sub {'
        . 'confess "Cannot assign a value to a read-only accessor" if @_ > 1;'
        . $meta_instance->inline_get_slot_value('$_[0]', "'$attr_name'")
    . '}';
    confess "Could not generate inline accessor because : $@" if $@;

    return $code;
}

sub generate_writer_method_inline {
    my $attr          = (shift)->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my $code = eval 'sub {'
        . $meta_instance->inline_set_slot_value('$_[0]', "'$attr_name'", '$_[1]')
    . '}';
    confess "Could not generate inline accessor because : $@" if $@;

    return $code;
}


sub generate_predicate_method_inline {
    my $attr          = (shift)->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my $code = eval 'sub {' .
       $meta_instance->inline_is_slot_initialized('$_[0]', "'$attr_name'")
    . '}';
    confess "Could not generate inline predicate because : $@" if $@;

    return $code;
}

sub generate_clearer_method_inline {
    my $attr          = (shift)->associated_attribute;
    my $attr_name     = $attr->name;
    my $meta_instance = $attr->associated_class->instance_metaclass;

    my $code = eval 'sub {'
        . $meta_instance->inline_deinitialize_slot('$_[0]', "'$attr_name'")
    . '}';
    confess "Could not generate inline clearer because : $@" if $@;

    return $code;
}

1;

__END__

=pod

=head1 NAME

Class::MOP::Method::Accessor - Method Meta Object for accessors

=head1 SYNOPSIS

    use Class::MOP::Method::Accessor;

    my $reader = Class::MOP::Method::Accessor->new(
        attribute     => $attribute,
        is_inline     => 1,
        accessor_type => 'reader',
    );

    $reader->body->($instance); # call the reader method

=head1 DESCRIPTION

This is a C<Class::MOP::Method> subclass which is used interally
by C<Class::MOP::Attribute> to generate accessor code. It can
handle generation of readers, writers, predicate and clearer
methods, both as closures and as more optimized inline methods.

=head1 METHODS

=over 4

=item B<new (%options)>

This creates the method based on the criteria in C<%options>,
these options are:

=over 4

=item I<attribute>

This must be an instance of C<Class::MOP::Attribute> which this
accessor is being generated for. This paramter is B<required>.

=item I<accessor_type>

This is a string from the following set; reader, writer, accessor,
predicate or clearer. This is used to determine which type of
method is to be generated.

=item I<is_inline>

This is a boolean to indicate if the method should be generated
as a closure, or as a more optimized inline version.

=back

=item B<accessor_type>

This returns the accessor type which was passed into C<new>.

=item B<is_inline>

This returns the boolean which was passed into C<new>.

=item B<associated_attribute>

This returns the attribute instance which was passed into C<new>.

=item B<initialize_body>

This will actually generate the method based on the specified
criteria passed to the constructor.

=back

=head2 Method Generators

These methods will generate appropriate code references for
the various types of accessors which are supported by
C<Class::MOP::Attribute>. The names pretty much explain it all.

=over 4

=item B<generate_accessor_method>

=item B<generate_accessor_method_inline>

=item B<generate_clearer_method>

=item B<generate_clearer_method_inline>

=item B<generate_predicate_method>

=item B<generate_predicate_method_inline>

=item B<generate_reader_method>

=item B<generate_reader_method_inline>

=item B<generate_writer_method>

=item B<generate_writer_method_inline>

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

