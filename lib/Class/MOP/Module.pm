
package Class::MOP::Module;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';
use Sub::Name    'subname';

our $VERSION   = '0.91';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Package';

sub _new {
    my $class = shift;
    return Class::MOP::Class->initialize($class)->new_object(@_)
        if $class ne __PACKAGE__;

    my $params = @_ == 1 ? $_[0] : {@_};
    return bless {

        # from Class::MOP::Package
        package   => $params->{package},
        namespace => \undef,

        # attributes
        version   => \undef,
        authority => \undef
    } => $class;
}


sub method_metaclass         { $_[0]->{'method_metaclass'}            }
sub wrapped_method_metaclass { $_[0]->{'wrapped_method_metaclass'}    }

sub _method_map              { $_[0]->{'methods'}                     }


sub version {  
    my $self = shift;
    ${$self->get_package_symbol({ sigil => '$', type => 'SCALAR', name => 'VERSION' })};
}

sub authority {  
    my $self = shift;
    ${$self->get_package_symbol({ sigil => '$', type => 'SCALAR', name => 'AUTHORITY' })};
}

sub identifier {
    my $self = shift;
    join '-' => (
        $self->name,
        ($self->version   || ()),
        ($self->authority || ()),
    );
}

sub create {
    confess "The Class::MOP::Module->create method has been made a private object method.\n";
}

sub _instantiate_module {
    my($self, $version, $authority) = @_;
    my $package_name = $self->name;

    Class::MOP::_is_valid_class_name($package_name)
        || confess "creation of $package_name failed: invalid package name";

    no strict 'refs';
    scalar %{ $package_name . '::' };    # touch the stash
    ${ $package_name . '::VERSION' }   = $version   if defined $version;
    ${ $package_name . '::AUTHORITY' } = $authority if defined $authority;

    return;
}

## Methods

sub wrap_method_body {
    my ( $self, %args ) = @_;

    ('CODE' eq ref $args{body})
        || confess "Your code block must be a CODE reference";

    $self->method_metaclass->wrap(
        package_name => $self->name,
        %args,
    );
}

sub add_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    my $body;
    if (blessed($method)) {
        $body = $method->body;
        if ($method->package_name ne $self->name) {
            $method = $method->clone(
                package_name => $self->name,
                name         => $method_name,
            ) if $method->can('clone');
        }

        $method->attach_to_class($self);
        $self->_method_map->{$method_name} = $method;
    }
    else {
        # If a raw code reference is supplied, its method object is not created.
        # The method object won't be created until required.
        $body = $method;
    }


    my ( $current_package, $current_name ) = Class::MOP::get_code_info($body);

    if ( !defined $current_name || $current_name eq '__ANON__' ) {
        my $full_method_name = ($self->name . '::' . $method_name);
        subname($full_method_name => $body);
    }

    $self->add_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name },
        $body,
    );
}

sub _code_is_mine {
    my ( $self, $code ) = @_;

    my ( $code_package, $code_name ) = Class::MOP::get_code_info($code);

    return $code_package && $code_package eq $self->name
        || ( $code_package eq 'constant' && $code_name eq '__ANON__' );
}

sub has_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    return defined($self->get_method($method_name));
}

sub get_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    my $method_map    = $self->_method_map;
    my $method_object = $method_map->{$method_name};
    my $code = $self->get_package_symbol({
        name  => $method_name,
        sigil => '&',
        type  => 'CODE',
    });

    unless ( $method_object && $method_object->body == ( $code || 0 ) ) {
        if ( $code && $self->_code_is_mine($code) ) {
            $method_object = $method_map->{$method_name}
                = $self->wrap_method_body(
                body                 => $code,
                name                 => $method_name,
                associated_metaclass => $self,
                );
        }
        else {
            delete $method_map->{$method_name};
            return undef;
        }
    }

    return $method_object;
}

sub remove_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    my $removed_method = delete $self->get_method_map->{$method_name};
    
    $self->remove_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name }
    );

    $removed_method->detach_from_class if $removed_method;

    $self->update_package_cache_flag; # still valid, since we just removed the method from the map

    return $removed_method;
}

sub get_method_list {
    my $self = shift;
    return grep { $self->has_method($_) } keys %{ $self->namespace };
}


1;

__END__

=pod

=head1 NAME 

Class::MOP::Module - Module Meta Object

=head1 DESCRIPTION

A module is essentially a L<Class::MOP::Package> with metadata, in our
case the version and authority.

=head1 INHERITANCE

B<Class::MOP::Module> is a subclass of L<Class::MOP::Package>.

=head1 METHODS

=over 4

=item B<< $metamodule->version >>

This is a read-only attribute which returns the C<$VERSION> of the
package, if one exists.

=item B<< $metamodule->authority >>

This is a read-only attribute which returns the C<$AUTHORITY> of the
package, if one exists.

=item B<< $metamodule->identifier >>

This constructs a string which combines the name, version and
authority.

=item B<< Class::MOP::Module->meta >>

This will return a L<Class::MOP::Class> instance for this class.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
