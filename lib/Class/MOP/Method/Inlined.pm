package Class::MOP::Method::Inlined;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken', 'looks_like_number', 'refaddr';

our $VERSION   = '0.81';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method::Generated';

sub _expected_method_class { $_[0]{_expected_method_class} }

sub _uninlined_body {
    my $self = shift;

    if ( my $super_method = $self->associated_metaclass->find_next_method_by_name( $self->name ) ) {
        if ( $super_method->isa(__PACKAGE__) ) {
            return $super_method->_uninlined_body;
        } else {
            return $super_method->body;
        }
    } else {
        return;
    }
}

sub can_be_inlined {
    my $self      = shift;
    my $metaclass = $self->associated_metaclass;
    my $class = $metaclass->name;

    if ( my $expected_class = $self->_expected_method_class ) {

        # if we are shadowing a method we first verify that it is
        # compatible with the definition we are replacing it with
        my $expected_method = $expected_class->can($self->name);

        my $warning
            = "Not inlining '" . $self->name . "' for $class since it is not"
            . " inheriting the default ${expected_class}::" . $self->name . "\n"
            . "If you are certain you don't need to inline your";

        if ( $self->isa("Class::MOP::Method::Constructor") ) {
            # FIXME kludge, refactor warning generation to a method
            $warning .= " constructor, specify inline_constructor => 0 in your"
                     . " call to $class->meta->make_immutable\n";
        }

        if ( my $actual_method = $class->can($self->name) ) {
            if ( refaddr($expected_method) == refaddr($actual_method) ) {
                # the method is what we wanted (probably Moose::Object::new)
                return 1;
            } elsif ( my $inherited_method = $metaclass->find_next_method_by_name( $self->name ) ) {
                # otherwise we have to check that the actual method is an
                # inlined version of what we're expecting
                if ( $inherited_method->isa(__PACKAGE__) ) {
                    if ( refaddr($inherited_method->_uninlined_body) == refaddr($expected_method) ) {
                        return 1;
                    }
                } elsif ( refaddr($inherited_method->body) == refaddr($expected_method) ) {
                    return 1;
                }

                # FIXME we can just rewrap them =P
                $warning .= " ('" . $self->name . "' has method modifiers which would be lost if it were inlined)\n"
                    if $inherited_method->isa('Class::MOP::Method::Wrapped');
            }
        } else {
            # This would be a rather weird case where we have no method
            # in the inheritance chain even though we're expecting one to be
            # there

            # this returns 1 for backwards compatibility for now
            return 1;
        }

        warn $warning;

        return 0;
    } else {
        # there is no expected class so we just install the constructor as a
        # new method
        return 1;
    }
}

