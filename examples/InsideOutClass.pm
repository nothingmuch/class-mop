
package InsideOutClass;

use strict;
use warnings;

use Class::MOP 'meta';

use Scalar::Util 'refaddr';

our $VERSION = '0.01';

__PACKAGE__->meta->superclasses('Class::MOP::Class');

sub construct_instance {
    my ($class, %params) = @_;
    my $instance = \(my $var);
    foreach my $attr (map { $_->{attribute} } $class->compute_all_applicable_attributes()) {
        # if the attr has an init_arg, use that, otherwise,
        # use the attributes name itself as the init_arg
        my $init_arg = $attr->has_init_arg() ? $attr->init_arg() : $attr->name;
        # try to fetch the init arg from the %params ...
        my $val;        
        $val = $params{$init_arg} if exists $params{$init_arg};
        # if nothing was in the %params, we can use the 
        # attribute's default value (if it has one)
        $val ||= $attr->default($instance) if $attr->has_default();
        # now add this to the instance structure
        $class->get_package_variable('%' . $attr->name)->{ refaddr($instance) } = $val;
    }    
    return $instance;
}


package InsideOutAttribute;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'reftype', 'refaddr';

use Class::MOP 'meta';

our $VERSION = '0.01';

__PACKAGE__->meta->superclasses('Class::MOP::Attribute');

{
    # this is just a utility routine to 
    # handle the details of accessors
    my $_inspect_accessor = sub {
        my ($attr_name, $type, $accessor) = @_;
    
        my %ACCESSOR_TEMPLATES = (
            'accessor' => 'sub {
                $' . $attr_name . '{ refaddr($_[0]) } = $_[1] if scalar(@_) == 2;
                $' . $attr_name . '{ refaddr($_[0]) };
            }',
            'reader' => 'sub {
                $' . $attr_name . '{ refaddr($_[0]) };
            }',
            'writer' => 'sub {
                $' . $attr_name . '{ refaddr($_[0]) } = $_[1];
            }',
            'predicate' => 'sub {
                defined($' . $attr_name . '{ refaddr($_[0]) }) ? 1 : 0;
            }'
        );    
    
        if (reftype($accessor) && reftype($accessor) eq 'HASH') {
            my ($name, $method) = each %{$accessor};
            return ($name, Class::MOP::Attribute::Accessor->wrap($method));        
        }
        else {
            my $method = eval $ACCESSOR_TEMPLATES{$type};
            confess "Could not create the $type for $attr_name CODE(\n" . $ACCESSOR_TEMPLATES{$type} . "\n) : $@" if $@;
            return ($accessor => Class::MOP::Attribute::Accessor->wrap($method));
        }    
    };

    sub install_accessors {
        my ($self, $class) = @_;
        (blessed($class) && $class->isa('Class::MOP::Class'))
            || confess "You must pass a Class::MOP::Class instance (or a subclass)";       
        
        $class->add_package_variable('%' . $self->name);
             
        $class->add_method(
            $_inspect_accessor->($class->name . '::' . $self->name, 'accessor' => $self->accessor())
        ) if $self->has_accessor();

        $class->add_method(            
            $_inspect_accessor->($class->name . '::' . $self->name, 'reader' => $self->reader())
        ) if $self->has_reader();
    
        $class->add_method(
            $_inspect_accessor->($class->name . '::' . $self->name, 'writer' => $self->writer())
        ) if $self->has_writer();
    
        $class->add_method(
            $_inspect_accessor->($class->name . '::' . $self->name, 'predicate' => $self->predicate())
        ) if $self->has_predicate();
        return;
    }
    
}

## &remove_attribute is left as an exercise for the reader :)

1;