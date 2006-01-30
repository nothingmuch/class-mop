
package Class::MOP::Attribute;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed';

use Class::MOP::Class;
use Class::MOP::Method;

our $VERSION = '0.01';

sub meta { Class::MOP::Class->initialize($_[0]) }

sub new {
    my $class   = shift;
    my $name    = shift;
    my %options = @_;    
        
    (defined $name && $name ne '')
        || confess "You must provide a name for the attribute";
    (!exists $options{reader} && !exists $options{writer})
        || confess "You cannot declare an accessor and reader and/or writer functions"
            if exists $options{accessor};
            
    bless {
        name     => $name,
        accessor => $options{accessor},
        reader   => $options{reader},
        writer   => $options{writer},
        init_arg => $options{init_arg},
        default  => $options{default}
    } => $class;
}

sub name         { (shift)->{name}             }

sub has_accessor { (shift)->{accessor} ? 1 : 0 }
sub accessor     { (shift)->{accessor}         } 

sub has_reader   { (shift)->{reader}   ? 1 : 0 }
sub reader       { (shift)->{reader}           }

sub has_writer   { (shift)->{writer}   ? 1 : 0 }
sub writer       { (shift)->{writer}           }

sub has_init_arg { (shift)->{init_arg} ? 1 : 0 }
sub init_arg     { (shift)->{init_arg}         }

sub has_default  { (shift)->{default}  ? 1 : 0 }
sub default      { (shift)->{default}          }

sub install_accessors {
    my ($self, $class) = @_;
    (blessed($class) && $class->isa('Class::MOP::Class'))
        || confess "You must pass a Class::MOP::Class instance (or a subclass)";    
        
    if ($self->has_accessor()) {
        $class->add_method($self->accessor() => Class::MOP::Attribute::Accessor->wrap(sub {
            $_[0]->{$self->name} = $_[1] if scalar(@_) == 2;
            $_[0]->{$self->name};
        }));
    }
    else {
        if ($self->has_reader()) {         
            $class->add_method($self->reader() => Class::MOP::Attribute::Accessor->wrap(sub { 
                $_[0]->{$self->name};
            }));        
        }
        if ($self->has_writer()) {
            $class->add_method($self->writer() => Class::MOP::Attribute::Accessor->wrap(sub {
                $_[0]->{$self->name} = $_[1];
                return;
            }));            
        }
    }
}

sub remove_accessors {
    my ($self, $class) = @_;
    (blessed($class) && $class->isa('Class::MOP::Class'))
        || confess "You must pass a Class::MOP::Class instance (or a subclass)";    
        
    if ($self->has_accessor()) {
        my $method = $class->get_method($self->accessor);
        $class->remove_method($self->accessor)
            if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
    }
    else {
        if ($self->has_reader()) {
            my $method = $class->get_method($self->reader);
            $class->remove_method($self->reader)
                if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
        }
        if ($self->has_writer()) {
            my $method = $class->get_method($self->writer);
            $class->remove_method($self->writer)
                if (blessed($method) && $method->isa('Class::MOP::Attribute::Accessor'));
        }
    }        
}

package Class::MOP::Attribute::Accessor;

use strict;
use warnings;

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