
package Class::MOP::Method::Accessor;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method';

sub new {
    my $class   = shift;
    my %options = @_;
    
    (exists $options{attribute})
        || confess "You must supply an attribute to construct with";
        
    (exists $options{accessor_type})
        || confess "You must supply an accessor_type to construct with"; 
        
    (blessed($options{attribute}) && $options{attribute}->isa('Class::MOP::Attribute'))
        || confess "You must supply an attribute which is a 'Class::MOP::Attribute' instance";    
        
    my $self = bless {
        # from our superclass
        '&!body'          => undef,
        # specific to this subclass
        '$!attribute'     => $options{attribute},
        '$!is_inline'     => ($options{is_inline} || 0),
        '$!accessor_type' => $options{accessor_type},        
    } => $class;
    
    # we don't want this creating 
    # a cycle in the code, if not 
    # needed
    weaken($self->{'$!attribute'});
    
    $self->intialize_body;
    
    return $self;
}

## accessors

sub associated_attribute { (shift)->{'$!attribute'}     }
sub accessor_type        { (shift)->{'$!accessor_type'} }
sub is_inline            { (shift)->{'$!is_inline'}     }

## factory 

sub intialize_body {
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

    my $code = eval 'sub {'
        . 'defined ' . $meta_instance->inline_get_slot_value('$_[0]', "'$attr_name'") . ' ? 1 : 0'
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

  # ... more to come later maybe

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<new>

=item B<intialize_body>

=item B<accessor_type>

=item B<is_inline>

=item B<associated_attribute>

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

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

