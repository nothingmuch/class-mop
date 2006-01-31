
package Class::MOP::Attribute;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype';

our $VERSION = '0.01';

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize($_[0]) 
}

# NOTE: (meta-circularity)
# This method will be replaces in the 
# boostrap section of Class::MOP, by 
# a new version which uses the 
# &Class::MOP::Class::construct_instance
# method to build an attribute meta-object
# which itself is described with attribute
# meta-objects. 
#     - Ain't meta-circularity grand? :)
sub new {
    my $class   = shift;
    my $name    = shift;
    my %options = @_;    
        
    (defined $name && $name)
        || confess "You must provide a name for the attribute";
    (!exists $options{reader} && !exists $options{writer})
        || confess "You cannot declare an accessor and reader and/or writer functions"
            if exists $options{accessor};
            
    bless {
        name      => $name,
        accessor  => $options{accessor},
        reader    => $options{reader},
        writer    => $options{writer},
        predicate => $options{predicate},
        init_arg  => $options{init_arg},
        default   => $options{default}
    } => $class;
}

sub name { $_[0]->{name} }

sub has_accessor  { defined($_[0]->{accessor})  ? 1 : 0 }
sub has_reader    { defined($_[0]->{reader})    ? 1 : 0 }
sub has_writer    { defined($_[0]->{writer})    ? 1 : 0 }
sub has_predicate { defined($_[0]->{predicate}) ? 1 : 0 }
sub has_init_arg  { defined($_[0]->{init_arg})  ? 1 : 0 }
sub has_default   { defined($_[0]->{default})   ? 1 : 0 }

sub accessor  { $_[0]->{accessor}  } 
sub reader    { $_[0]->{reader}    }
sub writer    { $_[0]->{writer}    }
sub predicate { $_[0]->{predicate} }
sub init_arg  { $_[0]->{init_arg}  }

sub default { 
    my $self = shift;
    if (reftype($self->{default}) && reftype($self->{default}) eq 'CODE') {
        # if the default is a CODE ref, then 
        # we pass in the instance and default
        # can return a value based on that 
        # instance. Somewhat crude, but works.
        return $self->{default}->(shift);
    }           
    $self->{default};
}

{
    # this is just a utility routine to 
    # handle the details of accessors
    my $_inspect_accessor = sub {
        my ($attr_name, $type, $accessor) = @_;
    
        my %ACCESSOR_TEMPLATES = (
            'accessor' => sub {
                $_[0]->{$attr_name} = $_[1] if scalar(@_) == 2;
                $_[0]->{$attr_name};
            },
            'reader' => sub { 
                $_[0]->{$attr_name};
            },
            'writer' => sub {
                $_[0]->{$attr_name} = $_[1];
                return;
            },
            'predicate' => sub {
                return defined $_[0]->{$attr_name} ? 1 : 0;
            }            
        );    
    
        if (reftype($accessor) && reftype($accessor) eq 'HASH') {
            my ($name, $method) = each %{$accessor};
            return ($name, Class::MOP::Attribute::Accessor->wrap($method));        
        }
        else {
            return ($accessor => Class::MOP::Attribute::Accessor->wrap($ACCESSOR_TEMPLATES{$type}));
        }    
    };

    sub install_accessors {
        my ($self, $class) = @_;
        (blessed($class) && $class->isa('Class::MOP::Class'))
            || confess "You must pass a Class::MOP::Class instance (or a subclass)";    
        
        $class->add_method(
            $_inspect_accessor->($self->name, 'accessor' => $self->accessor())
        ) if $self->has_accessor();

        $class->add_method(            
            $_inspect_accessor->($self->name, 'reader' => $self->reader())
        ) if $self->has_reader();
    
        $class->add_method(
            $_inspect_accessor->($self->name, 'writer' => $self->writer())
        ) if $self->has_writer();
    
        $class->add_method(
            $_inspect_accessor->($self->name, 'predicate' => $self->predicate())
        ) if $self->has_predicate();
    }
    
}

sub remove_accessors {
    my ($self, $class) = @_;
    (blessed($class) && $class->isa('Class::MOP::Class'))
        || confess "You must pass a Class::MOP::Class instance (or a subclass)";    
        
    if ($self->has_accessor()) {
        my $accessor = $self->accessor();
        if (reftype($accessor) && reftype($accessor) eq 'HASH') {
            ($accessor) = keys %{$accessor};
        }        
        my $method = $class->get_method($accessor);
        $class->remove_method($accessor)
            if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
    }
    else {
        if ($self->has_reader()) {
            my $reader = $self->reader();
            if (reftype($reader) && reftype($reader) eq 'HASH') {
                ($reader) = keys %{$reader};
            }            
            my $method = $class->get_method($reader);
            $class->remove_method($reader)
                if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
        }
        if ($self->has_writer()) {
            my $writer = $self->writer();
            if (reftype($writer) && reftype($writer) eq 'HASH') {
                ($writer) = keys %{$writer};
            }            
            my $method = $class->get_method($writer);
            $class->remove_method($writer)
                if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
        }
    }  
    
    if ($self->has_predicate()) {
        my $predicate = $self->predicate();
        if (reftype($predicate) && reftype($predicate) eq 'HASH') {
            ($predicate) = keys %{$predicate};
        }        
        my $method = $class->get_method($predicate);
        $class->remove_method($predicate)
            if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
    }          
}

package Class::MOP::Attribute::Accessor;

use strict;
use warnings;

use Class::MOP::Method;

our $VERSION = '0.01';

our @ISA = ('Class::MOP::Method');

1;

__END__

=pod

=head1 NAME 

Class::MOP::Attribute - Attribute Meta Object

=head1 SYNOPSIS
  
  Class::MOP::Attribute->new('$foo' => (
      accessor => 'foo',        # dual purpose get/set accessor
      init_arg => '-foo',       # class->new will look for a -foo key
      default  => 'BAR IS BAZ!' # if no -foo key is provided, use this
  ));
  
  Class::MOP::Attribute->new('$.bar' => (
      reader   => 'bar',        # getter
      writer   => 'set_bar',    # setter      
      init_arg => '-bar',       # class->new will look for a -bar key
      # no default value means it is undef
  ));

=head1 DESCRIPTION

The Attribute Protocol is almost entirely an invention of this module. This is
because Perl 5 does not have consistent notion of what is an attribute 
of a class. There are so many ways in which this is done, and very few 
(if any) are discoverable by this module.

So, all that said, this module attempts to inject some order into this 
chaos, by introducing a more consistent approach.

=head1 METHODS

=head2 Creation

=over 4

=item B<new ($name, %accessor_description, $class_initialization_arg, $default_value)>

=back 

=head2 Informational

=over 4

=item B<name>

=item B<accessor>

=item B<reader>

=item B<writer>

=item B<predicate>

=item B<init_arg>

=item B<default>

=back

=head2 Informational predicates

=over 4

=item B<has_accessor>

Returns true if this attribute uses a get/set accessor, and false 
otherwise

=item B<has_reader>

Returns true if this attribute has a reader, and false otherwise

=item B<has_writer>

Returns true if this attribute has a writer, and false otherwise

=item B<has_predicate>

Returns true if this attribute has a predicate, and false otherwise

=item B<has_init_arg>

Returns true if this attribute has a class intialization argument, and 
false otherwise

=item B<has_default>

Returns true if this attribute has a default value, and false 
otherwise.

=back

=head2 Attribute Accessor generation

=over 4

=item B<install_accessors ($class)>

This allows the attribute to generate and install code for it's own 
accessor methods. This is called by C<Class::MOP::Class::add_attribute>.

=item B<remove_accessors ($class)>

This allows the attribute to remove the method for it's own 
accessor. This is called by C<Class::MOP::Class::remove_attribute>.

=back

=head2 Introspection

=over 4

=item B<meta>

=back

=head1 AUTHOR

Stevan Little E<gt>stevan@iinteractive.comE<lt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut