
package Class::MOP::Method::Constructor;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken', 'looks_like_number';

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Method';

sub new {
    my $class   = shift;
    my %options = @_;
        
    (exists $options{options} && ref $options{options} eq 'HASH')
        || confess "You must pass a hash of options"; 
        
    (blessed $options{meta_instance} && $options{meta_instance}->isa('Class::MOP::Instance'))
        || confess "You must supply a meta-instance";        
    
    (exists $options{attributes} && ref $options{attributes} eq 'ARRAY')
        || confess "You must pass an array of options";        
        
    (blessed($_) && $_->isa('Class::MOP::Attribute'))
        || confess "You must supply a list of attributes which is a 'Class::MOP::Attribute' instance"
            for @{$options{attributes}};    
    
    my $self = bless {
        # from our superclass
        body          => undef,
        # specific to this subclass
        options       => $options{options},
        meta_instance => $options{meta_instance},
        attributes    => $options{attributes},        
    } => $class;

    # we don't want this creating 
    # a cycle in the code, if not 
    # needed
    weaken($self->{meta_instance});

    $self->intialize_body;

    return $self;    
}

## accessors 

sub options       { (shift)->{options}       }
sub meta_instance { (shift)->{meta_instance} }
sub attributes    { (shift)->{attributes}    }

## method

sub intialize_body {
    my $self = shift;
    # TODO:
    # the %options should also include a both 
    # a call 'initializer' and call 'SUPER::' 
    # options, which should cover approx 90% 
    # of the possible use cases (even if it 
    # requires some adaption on the part of 
    # the author, after all, nothing is free)
    my $source = 'sub {';
    $source .= "\n" . 'my ($class, %params) = @_;';
    $source .= "\n" . 'my $instance = ' . $self->meta_instance->inline_create_instance('$class');
    $source .= ";\n" . (join ";\n" => map { 
        $self->_generate_slot_initializer($_) 
    } 0 .. (@{$self->attributes} - 1));
    $source .= ";\n" . 'return $instance';
    $source .= ";\n" . '}'; 
    warn $source if $self->options->{debug};   
    
    my $code;
    {
        # NOTE:
        # create the nessecary lexicals
        # to be picked up in the eval 
        my $attrs = $self->attributes;
        
        $code = eval $source;
        confess "Could not eval the constructor :\n\n$source\n\nbecause :\n\n$@" if $@;
    }
    $self->{body} = $code;
}

sub _generate_slot_initializer {
    my $self  = shift;
    my $index = shift;
    
    my $attr = $self->attributes->[$index];
    
    my $default;
    if ($attr->has_default) {
        # NOTE:
        # default values can either be CODE refs
        # in which case we need to call them. Or 
        # they can be scalars (strings/numbers)
        # in which case we can just deal with them
        # in the code we eval.
        if ($attr->is_default_a_coderef) {
            $default = '$attrs->[' . $index . ']->default($instance)';
        }
        else {
            $default = $attr->default;
            # make sure to quote strings ...
            unless (looks_like_number($default)) {
                $default = "'$default'";
            }
        }
    }
    $self->meta_instance->inline_set_slot_value(
        '$instance', 
        ("'" . $attr->name . "'"), 
        ('$params{\'' . $attr->init_arg . '\'}' . (defined $default ? (' || ' . $default) : ''))
    );   
}

1;

1;

__END__

=pod

=head1 NAME 

Class::MOP::Method::Constructor - Method Meta Object for constructors

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<new>

=item B<attributes>

=item B<meta_instance>

=item B<options>

=item B<intialize_body>

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

