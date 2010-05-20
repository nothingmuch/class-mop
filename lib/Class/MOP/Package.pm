
package Class::MOP::Package;

use strict;
use warnings;

use Scalar::Util 'blessed', 'reftype';
use Carp         'confess';

our $VERSION   = '1.02';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Object';

# creation ...

sub initialize {
    my ( $class, @args ) = @_;

    unshift @args, "package" if @args % 2;

    my %options = @args;
    my $package_name = $options{package};


    # we hand-construct the class 
    # until we can bootstrap it
    if ( my $meta = Class::MOP::get_metaclass_by_name($package_name) ) {
        return $meta;
    } else {
        my $meta = ( ref $class || $class )->_new({
            'package'   => $package_name,
            %options,
        });
        Class::MOP::store_metaclass_by_name($package_name, $meta);

        return $meta;
    }
}

sub reinitialize {
    my ( $class, @args ) = @_;

    unshift @args, "package" if @args % 2;

    my %options = @args;
    my $package_name = delete $options{package};

    (defined $package_name && $package_name
      && (!blessed $package_name || $package_name->isa('Class::MOP::Package')))
        || confess "You must pass a package name or an existing Class::MOP::Package instance";

    $package_name = $package_name->name
        if blessed $package_name;

    Class::MOP::remove_metaclass_by_name($package_name);

    $class->initialize($package_name, %options); # call with first arg form for compat
}

sub _new {
    my $class = shift;

    return Class::MOP::Class->initialize($class)->new_object(@_)
        if $class ne __PACKAGE__;

    my $params = @_ == 1 ? $_[0] : {@_};

    return bless {
        package   => $params->{package},

        # NOTE:
        # because of issues with the Perl API
        # to the typeglob in some versions, we
        # need to just always grab a new
        # reference to the hash in the accessor.
        # Ideally we could just store a ref and
        # it would Just Work, but oh well :\

        namespace => \undef,

    } => $class;
}

# Attributes

# NOTE:
# all these attribute readers will be bootstrapped 
# away in the Class::MOP bootstrap section

sub namespace { 
    # NOTE:
    # because of issues with the Perl API 
    # to the typeglob in some versions, we 
    # need to just always grab a new 
    # reference to the hash here. Ideally 
    # we could just store a ref and it would
    # Just Work, but oh well :\    
    no strict 'refs';    
    \%{$_[0]->{'package'} . '::'} 
}

# utility methods

{
    my %SIGIL_MAP = (
        '$' => 'SCALAR',
        '@' => 'ARRAY',
        '%' => 'HASH',
        '&' => 'CODE',
    );
    
    sub _deconstruct_variable_name {
        my ($self, $variable) = @_;

        (defined $variable)
            || confess "You must pass a variable name";    

        my $sigil = substr($variable, 0, 1, '');

        (defined $sigil)
            || confess "The variable name must include a sigil";    

        (exists $SIGIL_MAP{$sigil})
            || confess "I do not recognize that sigil '$sigil'";    
        
        return ($variable, $sigil, $SIGIL_MAP{$sigil});
    }
}

# Class attributes

# ... these functions have to touch the symbol table itself,.. yuk

sub add_package_symbol {
    my ($self, $variable, $initial_value) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $pkg = $self->{'package'};

    no strict 'refs';
    no warnings 'redefine', 'misc', 'prototype';
    *{$pkg . '::' . $name} = ref $initial_value ? $initial_value : \$initial_value;
}

sub remove_package_glob {
    my ($self, $name) = @_;
    no strict 'refs';        
    delete ${$self->name . '::'}{$name};     
}

# ... these functions deal with stuff on the namespace level

sub has_package_symbol {
    my ( $self, $variable ) = @_;

    my ( $name, $sigil, $type )
        = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $namespace = $self->namespace;

    return 0 unless exists $namespace->{$name};

    my $entry_ref = \$namespace->{$name};
    if ( reftype($entry_ref) eq 'GLOB' ) {
        if ( $type eq 'SCALAR' ) {
            return defined( ${ *{$entry_ref}{SCALAR} } );
        }
        else {
            return defined( *{$entry_ref}{$type} );
        }
    }
    else {

        # a symbol table entry can be -1 (stub), string (stub with prototype),
        # or reference (constant)
        return $type eq 'CODE';
    }
}

sub get_package_symbol {
    my ($self, $variable) = @_;    

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    my $namespace = $self->namespace;

    # FIXME
    $self->add_package_symbol($variable)
        unless exists $namespace->{$name};

    my $entry_ref = \$namespace->{$name};

    if ( ref($entry_ref) eq 'GLOB' ) {
        return *{$entry_ref}{$type};
    }
    else {
        if ( $type eq 'CODE' ) {
            no strict 'refs';
            return \&{ $self->name . '::' . $name };
        }
        else {
            return undef;
        }
    }
}

sub remove_package_symbol {
    my ($self, $variable) = @_;

    my ($name, $sigil, $type) = ref $variable eq 'HASH'
        ? @{$variable}{qw[name sigil type]}
        : $self->_deconstruct_variable_name($variable);

    # FIXME:
    # no doubt this is grossly inefficient and 
    # could be done much easier and faster in XS

    my ($scalar_desc, $array_desc, $hash_desc, $code_desc) = (
        { sigil => '$', type => 'SCALAR', name => $name },
        { sigil => '@', type => 'ARRAY',  name => $name },
        { sigil => '%', type => 'HASH',   name => $name },
        { sigil => '&', type => 'CODE',   name => $name },
    );

    my ($scalar, $array, $hash, $code);
    if ($type eq 'SCALAR') {
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);     
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);     
    }
    elsif ($type eq 'ARRAY') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);     
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);
    }
    elsif ($type eq 'HASH') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);        
        $code   = $self->get_package_symbol($code_desc)   if $self->has_package_symbol($code_desc);      
    }
    elsif ($type eq 'CODE') {
        $scalar = $self->get_package_symbol($scalar_desc) if $self->has_package_symbol($scalar_desc);
        $array  = $self->get_package_symbol($array_desc)  if $self->has_package_symbol($array_desc);        
        $hash   = $self->get_package_symbol($hash_desc)   if $self->has_package_symbol($hash_desc);        
    }    
    else {
        confess "This should never ever ever happen";
    }
        
    $self->remove_package_glob($name);
    
    $self->add_package_symbol($scalar_desc => $scalar) if defined $scalar;      
    $self->add_package_symbol($array_desc  => $array)  if defined $array;    
    $self->add_package_symbol($hash_desc   => $hash)   if defined $hash;
    $self->add_package_symbol($code_desc   => $code)   if defined $code;            
}

sub list_all_package_symbols {
    my ($self, $type_filter) = @_;

    my $namespace = $self->namespace;
    return keys %{$namespace} unless defined $type_filter;
    
    # NOTE:
    # or we can filter based on 
    # type (SCALAR|ARRAY|HASH|CODE)
    if ( $type_filter eq 'CODE' ) {
        return grep { 
        (ref($namespace->{$_})
                ? (ref($namespace->{$_}) eq 'SCALAR')
                : (ref(\$namespace->{$_}) eq 'GLOB'
                   && defined(*{$namespace->{$_}}{CODE})));
        } keys %{$namespace};
    } else {
        return grep { *{$namespace->{$_}}{$type_filter} } keys %{$namespace};
    }
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Package - Package Meta Object

=head1 DESCRIPTION

The Package Protocol provides an abstraction of a Perl 5 package. A
package is basically namespace, and this module provides methods for
looking at and changing that namespace's symbol table.

=head1 METHODS

=over 4

=item B<< Class::MOP::Package->initialize($package_name) >>

This method creates a new C<Class::MOP::Package> instance which
represents specified package. If an existing metaclass object exists
for the package, that will be returned instead.

=item B<< Class::MOP::Package->reinitialize($package) >>

This method forcibly removes any existing metaclass for the package
before calling C<initialize>. In contrast to C<initialize>, you may
also pass an existing C<Class::MOP::Package> instance instead of just
a package name as C<$package>.

Do not call this unless you know what you are doing.

=item B<< $metapackage->name >>

This is returns the package's name, as passed to the constructor.

=item B<< $metapackage->namespace >>

This returns a hash reference to the package's symbol table. The keys
are symbol names and the values are typeglob references.

=item B<< $metapackage->add_package_symbol($variable_name, $initial_value) >>

This method accepts a variable name and an optional initial value. The
C<$variable_name> must contain a leading sigil.

This method creates the variable in the package's symbol table, and
sets it to the initial value if one was provided.

=item B<< $metapackage->get_package_symbol($variable_name) >>

Given a variable name, this method returns the variable as a reference
or undef if it does not exist. The C<$variable_name> must contain a
leading sigil.

=item B<< $metapackage->has_package_symbol($variable_name) >>

Returns true if there is a package variable defined for
C<$variable_name>. The C<$variable_name> must contain a leading sigil.

=item B<< $metapackage->remove_package_symbol($variable_name) >>

This will remove the package variable specified C<$variable_name>. The
C<$variable_name> must contain a leading sigil.

=item B<< $metapackage->remove_package_glob($glob_name) >>

Given the name of a glob, this will remove that glob from the
package's symbol table. Glob names do not include a sigil. Removing
the glob removes all variables and subroutines with the specified
name.

=item B<< $metapackage->list_all_package_symbols($type_filter) >>

This will list all the glob names associated with the current
package. These names do not have leading sigils.

You can provide an optional type filter, which should be one of
'SCALAR', 'ARRAY', 'HASH', or 'CODE'.

=item B<< $metapackage->get_all_package_symbols($type_filter) >>

This works much like C<list_all_package_symbols>, but it returns a
hash reference. The keys are glob names and the values are references
to the value for that name.

=item B<< Class::MOP::Package->meta >>

This will return a L<Class::MOP::Class> instance for this class.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2010 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
