
package Class::MOP::Class;

use strict;
use warnings;

use Class::MOP::Immutable;
use Class::MOP::Instance;
use Class::MOP::Method::Wrapped;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken';

our $VERSION   = '0.63';
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Module';

# Creation

sub initialize {
    my $class        = shift;
    my $package_name = shift;
    (defined $package_name && $package_name && !blessed($package_name))
        || confess "You must pass a package name and it cannot be blessed";
    return Class::MOP::get_metaclass_by_name($package_name)
        || $class->construct_class_instance('package' => $package_name, @_);
}

sub reinitialize {
    my $class        = shift;
    my $package_name = shift;
    (defined $package_name && $package_name && !blessed($package_name))
        || confess "You must pass a package name and it cannot be blessed";
    Class::MOP::remove_metaclass_by_name($package_name);
    $class->construct_class_instance('package' => $package_name, @_);
}

# NOTE: (meta-circularity)
# this is a special form of &construct_instance
# (see below), which is used to construct class
# meta-object instances for any Class::MOP::*
# class. All other classes will use the more
# normal &construct_instance.
sub construct_class_instance {
    my $class        = shift;
    my %options      = @_;
    my $package_name = $options{'package'};
    (defined $package_name && $package_name)
        || confess "You must pass a package name";
    # NOTE:
    # return the metaclass if we have it cached,
    # and it is still defined (it has not been
    # reaped by DESTROY yet, which can happen
    # annoyingly enough during global destruction)

    if (defined(my $meta = Class::MOP::get_metaclass_by_name($package_name))) {
        return $meta;
    }

    # NOTE:
    # we need to deal with the possibility
    # of class immutability here, and then
    # get the name of the class appropriately
    $class = (blessed($class)
                    ? ($class->is_immutable
                        ? $class->get_mutable_metaclass_name()
                        : blessed($class))
                    : $class);

    # now create the metaclass
    my $meta;
    if ($class eq 'Class::MOP::Class') {
        no strict 'refs';
        $meta = bless {
            # inherited from Class::MOP::Package
            '$!package'             => $package_name,

            # NOTE:
            # since the following attributes will
            # actually be loaded from the symbol
            # table, and actually bypass the instance
            # entirely, we can just leave these things
            # listed here for reference, because they
            # should not actually have a value associated
            # with the slot.
            '%!namespace'           => \undef,
            # inherited from Class::MOP::Module
            '$!version'             => \undef,
            '$!authority'           => \undef,
            # defined in Class::MOP::Class
            '@!superclasses'        => \undef,

            '%!methods'             => {},
            '%!attributes'          => {},
            '$!attribute_metaclass' => $options{'attribute_metaclass'} || 'Class::MOP::Attribute',
            '$!method_metaclass'    => $options{'method_metaclass'}    || 'Class::MOP::Method',
            '$!instance_metaclass'  => $options{'instance_metaclass'}  || 'Class::MOP::Instance',
            
            ## uber-private variables
            # NOTE:
            # this starts out as undef so that 
            # we can tell the first time the 
            # methods are fetched
            # - SL
            '$!_package_cache_flag'       => undef,  
            '$!_meta_instance'            => undef,          
        } => $class;
    }
    else {
        # NOTE:
        # it is safe to use meta here because
        # class will always be a subclass of
        # Class::MOP::Class, which defines meta
        $meta = $class->meta->construct_instance(%options)
    }

    # and check the metaclass compatibility
    $meta->check_metaclass_compatability();  

    Class::MOP::store_metaclass_by_name($package_name, $meta);

    # NOTE:
    # we need to weaken any anon classes
    # so that they can call DESTROY properly
    Class::MOP::weaken_metaclass($package_name) if $meta->is_anon_class;

    $meta;
}

sub reset_package_cache_flag  { (shift)->{'$!_package_cache_flag'} = undef } 
sub update_package_cache_flag {
    my $self = shift;
    # NOTE:
    # we can manually update the cache number 
    # since we are actually adding the method
    # to our cache as well. This avoids us 
    # having to regenerate the method_map.
    # - SL    
    $self->{'$!_package_cache_flag'} = Class::MOP::check_package_cache_flag($self->name);    
}

sub check_metaclass_compatability {
    my $self = shift;

    # this is always okay ...
    return if blessed($self)            eq 'Class::MOP::Class'   &&
              $self->instance_metaclass eq 'Class::MOP::Instance';

    my @class_list = $self->linearized_isa;
    shift @class_list; # shift off $self->name

    foreach my $class_name (@class_list) {
        my $meta = Class::MOP::get_metaclass_by_name($class_name) || next;

        # NOTE:
        # we need to deal with the possibility
        # of class immutability here, and then
        # get the name of the class appropriately
        my $meta_type = ($meta->is_immutable
                            ? $meta->get_mutable_metaclass_name()
                            : blessed($meta));

        ($self->isa($meta_type))
            || confess $self->name . "->meta => (" . (blessed($self)) . ")" .
                       " is not compatible with the " .
                       $class_name . "->meta => (" . ($meta_type)     . ")";
        # NOTE:
        # we also need to check that instance metaclasses
        # are compatabile in the same the class.
        ($self->instance_metaclass->isa($meta->instance_metaclass))
            || confess $self->name . "->meta => (" . ($self->instance_metaclass) . ")" .
                       " is not compatible with the " .
                       $class_name . "->meta => (" . ($meta->instance_metaclass) . ")";
    }
}

## ANON classes

{
    # NOTE:
    # this should be sufficient, if you have a
    # use case where it is not, write a test and
    # I will change it.
    my $ANON_CLASS_SERIAL = 0;

    # NOTE:
    # we need a sufficiently annoying prefix
    # this should suffice for now, this is
    # used in a couple of places below, so
    # need to put it up here for now.
    my $ANON_CLASS_PREFIX = 'Class::MOP::Class::__ANON__::SERIAL::';

    sub is_anon_class {
        my $self = shift;
        no warnings 'uninitialized';
        $self->name =~ /^$ANON_CLASS_PREFIX/ ? 1 : 0;
    }

    sub create_anon_class {
        my ($class, %options) = @_;
        my $package_name = $ANON_CLASS_PREFIX . ++$ANON_CLASS_SERIAL;
        return $class->create($package_name, %options);
    }

    # NOTE:
    # this will only get called for
    # anon-classes, all other calls
    # are assumed to occur during
    # global destruction and so don't
    # really need to be handled explicitly
    sub DESTROY {
        my $self = shift;
        no warnings 'uninitialized';
        return unless $self->name =~ /^$ANON_CLASS_PREFIX/;
        my ($serial_id) = ($self->name =~ /^$ANON_CLASS_PREFIX(\d+)/);
        no strict 'refs';
        foreach my $key (keys %{$ANON_CLASS_PREFIX . $serial_id}) {
            delete ${$ANON_CLASS_PREFIX . $serial_id}{$key};
        }
        delete ${'main::' . $ANON_CLASS_PREFIX}{$serial_id . '::'};
    }

}

# creating classes with MOP ...

sub create {
    my $class        = shift;
    my $package_name = shift;

    (defined $package_name && $package_name)
        || confess "You must pass a package name";

    (scalar @_ % 2 == 0)
        || confess "You much pass all parameters as name => value pairs " .
                   "(I found an uneven number of params in \@_)";

    my (%options) = @_;
    
    (ref $options{superclasses} eq 'ARRAY')
        || confess "You must pass an ARRAY ref of superclasses"
            if exists $options{superclasses};
            
    (ref $options{attributes} eq 'ARRAY')
        || confess "You must pass an ARRAY ref of attributes"
            if exists $options{attributes};      
            
    (ref $options{methods} eq 'HASH')
        || confess "You must pass an HASH ref of methods"
            if exists $options{methods};                  

    my $code = "package $package_name;";
    $code .= "\$$package_name\:\:VERSION = '" . $options{version} . "';"
        if exists $options{version};
    $code .= "\$$package_name\:\:AUTHORITY = '" . $options{authority} . "';"
        if exists $options{authority};

    eval $code;
    confess "creation of $package_name failed : $@" if $@;

    my $meta = $class->initialize($package_name);

    $meta->add_method('meta' => sub {
        $class->initialize(blessed($_[0]) || $_[0]);
    });

    $meta->superclasses(@{$options{superclasses}})
        if exists $options{superclasses};
    # NOTE:
    # process attributes first, so that they can
    # install accessors, but locally defined methods
    # can then overwrite them. It is maybe a little odd, but
    # I think this should be the order of things.
    if (exists $options{attributes}) {
        foreach my $attr (@{$options{attributes}}) {
            $meta->add_attribute($attr);
        }
    }
    if (exists $options{methods}) {
        foreach my $method_name (keys %{$options{methods}}) {
            $meta->add_method($method_name, $options{methods}->{$method_name});
        }
    }
    return $meta;
}

## Attribute readers

# NOTE:
# all these attribute readers will be bootstrapped
# away in the Class::MOP bootstrap section

sub get_attribute_map   { $_[0]->{'%!attributes'}          }
sub attribute_metaclass { $_[0]->{'$!attribute_metaclass'} }
sub method_metaclass    { $_[0]->{'$!method_metaclass'}    }
sub instance_metaclass  { $_[0]->{'$!instance_metaclass'}  }

# FIXME:
# this is a prime canidate for conversion to XS
sub get_method_map {
    my $self = shift;
    
    if (defined $self->{'$!_package_cache_flag'} && 
                $self->{'$!_package_cache_flag'} == Class::MOP::check_package_cache_flag($self->name)) {
        return $self->{'%!methods'};
    }
    
    my $map  = $self->{'%!methods'};

    my $class_name       = $self->name;
    my $method_metaclass = $self->method_metaclass;

    my %all_code = $self->get_all_package_symbols('CODE');

    foreach my $symbol (keys %all_code) {
        my $code = $all_code{$symbol};

        next if exists  $map->{$symbol} &&
                defined $map->{$symbol} &&
                        $map->{$symbol}->body == $code;

        my ($pkg, $name) = Class::MOP::get_code_info($code);
        
        # NOTE:
        # in 5.10 constant.pm the constants show up 
        # as being in the right package, but in pre-5.10
        # they show up as constant::__ANON__ so we 
        # make an exception here to be sure that things
        # work as expected in both.
        # - SL
        unless ($pkg eq 'constant' && $name eq '__ANON__') {
            next if ($pkg  || '') ne $class_name ||
                    (($name || '') ne '__ANON__' && ($pkg  || '') ne $class_name);
        }

        $map->{$symbol} = $method_metaclass->wrap(
            $code,
            package_name => $class_name,
            name         => $symbol,
        );
    }

    return $map;
}

# Instance Construction & Cloning

sub new_object {
    my $class = shift;
    # NOTE:
    # we need to protect the integrity of the
    # Class::MOP::Class singletons here, so we
    # delegate this to &construct_class_instance
    # which will deal with the singletons
    return $class->construct_class_instance(@_)
        if $class->name->isa('Class::MOP::Class');
    return $class->construct_instance(@_);
}

sub construct_instance {
    my ($class, %params) = @_;
    my $meta_instance = $class->get_meta_instance();
    my $instance = $meta_instance->create_instance();
    foreach my $attr ($class->compute_all_applicable_attributes()) {
        $attr->initialize_instance_slot($meta_instance, $instance, \%params);
    }
    # NOTE:
    # this will only work for a HASH instance type
    if ($class->is_anon_class) {
        (Scalar::Util::reftype($instance) eq 'HASH')
            || confess "Currently only HASH based instances are supported with instance of anon-classes";
        # NOTE:
        # At some point we should make this official
        # as a reserved slot name, but right now I am
        # going to keep it here.
        # my $RESERVED_MOP_SLOT = '__MOP__';
        $instance->{'__MOP__'} = $class;
    }
    return $instance;
}


sub get_meta_instance {
    my $self = shift;
    # NOTE:
    # just about any fiddling with @ISA or 
    # any fiddling with attributes will 
    # also fiddle with the symbol table 
    # and therefore invalidate the package 
    # cache, in which case we should blow 
    # away the meta-instance cache. Of course
    # this will invalidate it more often then 
    # is probably needed, but better safe 
    # then sorry.
    # - SL
    $self->{'$!_meta_instance'} = undef
        if defined $self->{'$!_package_cache_flag'} && 
                   $self->{'$!_package_cache_flag'} == Class::MOP::check_package_cache_flag($self->name);
    $self->{'$!_meta_instance'} ||= $self->instance_metaclass->new(
        $self,
        $self->compute_all_applicable_attributes()
    );
}

sub clone_object {
    my $class    = shift;
    my $instance = shift;
    (blessed($instance) && $instance->isa($class->name))
        || confess "You must pass an instance of the metaclass (" . $class->name . "), not ($instance)";

    # NOTE:
    # we need to protect the integrity of the
    # Class::MOP::Class singletons here, they
    # should not be cloned.
    return $instance if $instance->isa('Class::MOP::Class');
    $class->clone_instance($instance, @_);
}

sub clone_instance {
    my ($class, $instance, %params) = @_;
    (blessed($instance))
        || confess "You can only clone instances, ($instance) is not a blessed instance";
    my $meta_instance = $class->get_meta_instance();
    my $clone = $meta_instance->clone_instance($instance);
    foreach my $attr ($class->compute_all_applicable_attributes()) {
        if ( defined( my $init_arg = $attr->init_arg ) ) {
            if (exists $params{$init_arg}) {
                $attr->set_value($clone, $params{$init_arg});
            }
        }
    }
    return $clone;
}

sub rebless_instance {
    my ($self, $instance, %params) = @_;

    my $old_metaclass;
    if ($instance->can('meta')) {
        ($instance->meta->isa('Class::MOP::Class'))
            || confess 'Cannot rebless instance if ->meta is not an instance of Class::MOP::Class';
        $old_metaclass = $instance->meta;
    }
    else {
        $old_metaclass = $self->initialize(blessed($instance));
    }

    my $meta_instance = $self->get_meta_instance();

    $self->name->isa($old_metaclass->name)
        || confess "You may rebless only into a subclass of (". $old_metaclass->name ."), of which (". $self->name .") isn't.";

    # rebless!
    $meta_instance->rebless_instance_structure($instance, $self);

    foreach my $attr ( $self->compute_all_applicable_attributes ) {
        if ( $attr->has_value($instance) ) {
            if ( defined( my $init_arg = $attr->init_arg ) ) {
                $params{$init_arg} = $attr->get_value($instance)
                    unless exists $params{$init_arg};
            } 
            else {
                $attr->set_value($instance, $attr->get_value($instance));
            }
        }
    }

    foreach my $attr ($self->compute_all_applicable_attributes) {
        $attr->initialize_instance_slot($meta_instance, $instance, \%params);
    }
    
    $instance;
}

# Inheritance

sub superclasses {
    my $self     = shift;
    my $var_spec = { sigil => '@', type => 'ARRAY', name => 'ISA' };
    if (@_) {
        my @supers = @_;
        @{$self->get_package_symbol($var_spec)} = @supers;
        # NOTE:
        # we need to check the metaclass
        # compatibility here so that we can
        # be sure that the superclass is
        # not potentially creating an issues
        # we don't know about
        $self->check_metaclass_compatability();
    }
    @{$self->get_package_symbol($var_spec)};
}

sub subclasses {
    my $self = shift;

    my $super_class = $self->name;
    my @derived_classes;
    
    my $find_derived_classes;
    $find_derived_classes = sub {
        my ($outer_class) = @_;

        my $symbol_table_hashref = do { no strict 'refs'; \%{"${outer_class}::"} };

        SYMBOL:
        for my $symbol ( keys %$symbol_table_hashref ) {
            next SYMBOL if $symbol !~ /\A (\w+):: \z/x;
            my $inner_class = $1;

            next SYMBOL if $inner_class eq 'SUPER';    # skip '*::SUPER'

            my $class =
              $outer_class
              ? "${outer_class}::$inner_class"
              : $inner_class;

            if ( $class->isa($super_class) and $class ne $super_class ) {
                push @derived_classes, $class;
            }

            next SYMBOL if $class eq 'main';           # skip 'main::*'

            $find_derived_classes->($class);
        }
    };

    my $root_class = q{};
    $find_derived_classes->($root_class);

    undef $find_derived_classes;

    @derived_classes = sort { $a->isa($b) ? 1 : $b->isa($a) ? -1 : 0 } @derived_classes;

    return @derived_classes;
}


sub linearized_isa {
    return @{ mro::get_linear_isa( (shift)->name ) };
}

sub class_precedence_list {
    my $self = shift;
    my $name = $self->name;

    unless (Class::MOP::IS_RUNNING_ON_5_10()) { 
        # NOTE:
        # We need to check for circular inheritance here
        # if we are are not on 5.10, cause 5.8 detects it 
        # late. This will do nothing if all is well, and 
        # blow up otherwise. Yes, it's an ugly hack, better
        # suggestions are welcome.        
        # - SL
        ($name || return)->isa('This is a test for circular inheritance') 
    }

    # if our mro is c3, we can 
    # just grab the linear_isa
    if (mro::get_mro($name) eq 'c3') {
        return @{ mro::get_linear_isa($name) }
    }
    else {
        # NOTE:
        # we can't grab the linear_isa for dfs
        # since it has all the duplicates 
        # already removed.
        return (
            $name,
            map {
                $self->initialize($_)->class_precedence_list()
            } $self->superclasses()
        );
    }
}

## Methods

sub add_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    my $body;
    if (blessed($method)) {
        $body = $method->body;
        if ($method->package_name ne $self->name && 
            $method->name         ne $method_name) {
            warn "Hello there, got something for you." 
                . " Method says " . $method->package_name . " " . $method->name
                . " Class says " . $self->name . " " . $method_name;
            $method = $method->clone(
                package_name => $self->name,
                name         => $method_name            
            ) if $method->can('clone');
        }
    }
    else {
        $body = $method;
        ('CODE' eq ref($body))
            || confess "Your code block must be a CODE reference";
        $method = $self->method_metaclass->wrap(
            $body => (
                package_name => $self->name,
                name         => $method_name
            )
        );
    }
    $self->get_method_map->{$method_name} = $method;
    
    my $full_method_name = ($self->name . '::' . $method_name);    
    $self->add_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name }, 
        Class::MOP::subname($full_method_name => $body)
    );
    $self->update_package_cache_flag;    
}

{
    my $fetch_and_prepare_method = sub {
        my ($self, $method_name) = @_;
        # fetch it locally
        my $method = $self->get_method($method_name);
        # if we dont have local ...
        unless ($method) {
            # try to find the next method
            $method = $self->find_next_method_by_name($method_name);
            # die if it does not exist
            (defined $method)
                || confess "The method '$method_name' is not found in the inheritance hierarchy for class " . $self->name;
            # and now make sure to wrap it
            # even if it is already wrapped
            # because we need a new sub ref
            $method = Class::MOP::Method::Wrapped->wrap($method);
        }
        else {
            # now make sure we wrap it properly
            $method = Class::MOP::Method::Wrapped->wrap($method)
                unless $method->isa('Class::MOP::Method::Wrapped');
        }
        $self->add_method($method_name => $method);
        return $method;
    };

    sub add_before_method_modifier {
        my ($self, $method_name, $method_modifier) = @_;
        (defined $method_name && $method_name)
            || confess "You must pass in a method name";
        my $method = $fetch_and_prepare_method->($self, $method_name);
        $method->add_before_modifier(
            Class::MOP::subname(':before' => $method_modifier)
        );
    }

    sub add_after_method_modifier {
        my ($self, $method_name, $method_modifier) = @_;
        (defined $method_name && $method_name)
            || confess "You must pass in a method name";
        my $method = $fetch_and_prepare_method->($self, $method_name);
        $method->add_after_modifier(
            Class::MOP::subname(':after' => $method_modifier)
        );
    }

    sub add_around_method_modifier {
        my ($self, $method_name, $method_modifier) = @_;
        (defined $method_name && $method_name)
            || confess "You must pass in a method name";
        my $method = $fetch_and_prepare_method->($self, $method_name);
        $method->add_around_modifier(
            Class::MOP::subname(':around' => $method_modifier)
        );
    }

    # NOTE:
    # the methods above used to be named like this:
    #    ${pkg}::${method}:(before|after|around)
    # but this proved problematic when using one modifier
    # to wrap multiple methods (something which is likely
    # to happen pretty regularly IMO). So instead of naming
    # it like this, I have chosen to just name them purely
    # with their modifier names, like so:
    #    :(before|after|around)
    # The fact is that in a stack trace, it will be fairly
    # evident from the context what method they are attached
    # to, and so don't need the fully qualified name.
}

sub alias_method {
    my ($self, $method_name, $method) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    my $body = (blessed($method) ? $method->body : $method);
    ('CODE' eq ref($body))
        || confess "Your code block must be a CODE reference";

    $self->add_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name } => $body
    );
    $self->update_package_cache_flag;     
}

sub has_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    return 0 unless exists $self->get_method_map->{$method_name};
    return 1;
}

sub get_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    # NOTE:
    # I don't really need this here, because
    # if the method_map is missing a key it
    # will just return undef for me now
    # return unless $self->has_method($method_name);

    return $self->get_method_map->{$method_name};
}

sub remove_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    my $removed_method = delete $self->get_method_map->{$method_name};
    
    $self->remove_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name }
    );
    
    $self->update_package_cache_flag;        

    return $removed_method;
}

sub get_method_list {
    my $self = shift;
    keys %{$self->get_method_map};
}

sub find_method_by_name {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name to find";
    foreach my $class ($self->linearized_isa) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        return $meta->get_method($method_name)
            if $meta->has_method($method_name);
    }
    return;
}

sub compute_all_applicable_methods {
    my $self = shift;
    my (@methods, %seen_method);
    foreach my $class ($self->linearized_isa) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        foreach my $method_name ($meta->get_method_list()) {
            next if exists $seen_method{$method_name};
            $seen_method{$method_name}++;
            push @methods => {
                name  => $method_name,
                class => $class,
                code  => $meta->get_method($method_name)
            };
        }
    }
    return @methods;
}

sub find_all_methods_by_name {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name to find";
    my @methods;
    foreach my $class ($self->linearized_isa) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        push @methods => {
            name  => $method_name,
            class => $class,
            code  => $meta->get_method($method_name)
        } if $meta->has_method($method_name);
    }
    return @methods;
}

sub find_next_method_by_name {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name to find";
    my @cpl = $self->linearized_isa;
    shift @cpl; # discard ourselves
    foreach my $class (@cpl) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        return $meta->get_method($method_name)
            if $meta->has_method($method_name);
    }
    return;
}

## Attributes

sub add_attribute {
    my $self      = shift;
    # either we have an attribute object already
    # or we need to create one from the args provided
    my $attribute = blessed($_[0]) ? $_[0] : $self->attribute_metaclass->new(@_);
    # make sure it is derived from the correct type though
    ($attribute->isa('Class::MOP::Attribute'))
        || confess "Your attribute must be an instance of Class::MOP::Attribute (or a subclass)";

    # first we attach our new attribute
    # because it might need certain information
    # about the class which it is attached to
    $attribute->attach_to_class($self);

    # then we remove attributes of a conflicting
    # name here so that we can properly detach
    # the old attr object, and remove any
    # accessors it would have generated
    $self->remove_attribute($attribute->name)
        if $self->has_attribute($attribute->name);

    # then onto installing the new accessors
    $attribute->install_accessors();
    $self->get_attribute_map->{$attribute->name} = $attribute;
}

sub has_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    exists $self->get_attribute_map->{$attribute_name} ? 1 : 0;
}

sub get_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    return $self->get_attribute_map->{$attribute_name}
    # NOTE:
    # this will return undef anyway, so no need ...
    #    if $self->has_attribute($attribute_name);
    #return;
}

sub remove_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    my $removed_attribute = $self->get_attribute_map->{$attribute_name};
    return unless defined $removed_attribute;
    delete $self->get_attribute_map->{$attribute_name};
    $removed_attribute->remove_accessors();
    $removed_attribute->detach_from_class();
    return $removed_attribute;
}

sub get_attribute_list {
    my $self = shift;
    keys %{$self->get_attribute_map};
}

sub compute_all_applicable_attributes {
    my $self = shift;
    my (@attrs, %seen_attr);
    foreach my $class ($self->linearized_isa) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        foreach my $attr_name ($meta->get_attribute_list()) {
            next if exists $seen_attr{$attr_name};
            $seen_attr{$attr_name}++;
            push @attrs => $meta->get_attribute($attr_name);
        }
    }
    return @attrs;
}

sub find_attribute_by_name {
    my ($self, $attr_name) = @_;
    foreach my $class ($self->linearized_isa) {
        # fetch the meta-class ...
        my $meta = $self->initialize($class);
        return $meta->get_attribute($attr_name)
            if $meta->has_attribute($attr_name);
    }
    return;
}

## Class closing

sub is_mutable   { 1 }
sub is_immutable { 0 }

# NOTE:
# Why I changed this (groditi)
#  - One Metaclass may have many Classes through many Metaclass instances
#  - One Metaclass should only have one Immutable Transformer instance
#  - Each Class may have different Immutabilizing options
#  - Therefore each Metaclass instance may have different Immutabilizing options
#  - We need to store one Immutable Transformer instance per Metaclass
#  - We need to store one set of Immutable Transformer options per Class
#  - Upon make_mutable we may delete the Immutabilizing options
#  - We could clean the immutable Transformer instance when there is no more
#      immutable Classes of that type, but we can also keep it in case
#      another class with this same Metaclass becomes immutable. It is a case
#      of trading of storing an instance to avoid unnecessary instantiations of
#      Immutable Transformers. You may view this as a memory leak, however
#      Because we have few Metaclasses, in practice it seems acceptable
#  - To allow Immutable Transformers instances to be cleaned up we could weaken
#      the reference stored in  $IMMUTABLE_TRANSFORMERS{$class} and ||= should DWIM

{

    my %IMMUTABLE_TRANSFORMERS;
    my %IMMUTABLE_OPTIONS;

    sub get_immutable_options {
        my $self = shift;
        return if $self->is_mutable;
        confess "unable to find immutabilizing options"
            unless exists $IMMUTABLE_OPTIONS{$self->name};
        my %options = %{$IMMUTABLE_OPTIONS{$self->name}};
        delete $options{IMMUTABLE_TRANSFORMER};
        return \%options;
    }

    sub get_immutable_transformer {
        my $self = shift;
        if( $self->is_mutable ){
            my $class = blessed $self || $self;
            return $IMMUTABLE_TRANSFORMERS{$class} ||= $self->create_immutable_transformer;
        }
        confess "unable to find transformer for immutable class"
            unless exists $IMMUTABLE_OPTIONS{$self->name};
        return $IMMUTABLE_OPTIONS{$self->name}->{IMMUTABLE_TRANSFORMER};
    }

    sub make_immutable {
        my $self = shift;
        my %options = @_;

        my $transformer = $self->get_immutable_transformer;
        $transformer->make_metaclass_immutable($self, \%options);
        $IMMUTABLE_OPTIONS{$self->name} =
            { %options,  IMMUTABLE_TRANSFORMER => $transformer };

        if( exists $options{debug} && $options{debug} ){
            print STDERR "# of Metaclass options:      ", keys %IMMUTABLE_OPTIONS;
            print STDERR "# of Immutable transformers: ", keys %IMMUTABLE_TRANSFORMERS;
        }

        1;
    }

    sub make_mutable{
        my $self = shift;
        return if $self->is_mutable;
        my $options = delete $IMMUTABLE_OPTIONS{$self->name};
        confess "unable to find immutabilizing options" unless ref $options;
        my $transformer = delete $options->{IMMUTABLE_TRANSFORMER};
        $transformer->make_metaclass_mutable($self, $options);
        1;
    }
}

sub create_immutable_transformer {
    my $self = shift;
    my $class = Class::MOP::Immutable->new($self, {
        read_only   => [qw/superclasses/],
        cannot_call => [qw/
           add_method
           alias_method
           remove_method
           add_attribute
           remove_attribute
           remove_package_symbol
        /],
        memoize     => {
           class_precedence_list             => 'ARRAY',
           linearized_isa                    => 'ARRAY',
           compute_all_applicable_attributes => 'ARRAY',
           get_meta_instance                 => 'SCALAR',
           get_method_map                    => 'SCALAR',
        },
        # NOTE:
        # this is ugly, but so are typeglobs, 
        # so whattayahgonnadoboutit
        # - SL
        wrapped => { 
            add_package_symbol => sub {
                my $original = shift;
                confess "Cannot add package symbols to an immutable metaclass" 
                    unless (caller(2))[3] eq 'Class::MOP::Package::get_package_symbol'; 
                goto $original->body;
            },
        },
    });
    return $class;
}

1;

__END__

=pod

=head1 NAME

Class::MOP::Class - Class Meta Object

=head1 SYNOPSIS

  # assuming that class Foo
  # has been defined, you can

  # use this for introspection ...

  # add a method to Foo ...
  Foo->meta->add_method('bar' => sub { ... })

  # get a list of all the classes searched
  # the method dispatcher in the correct order
  Foo->meta->class_precedence_list()

  # remove a method from Foo
  Foo->meta->remove_method('bar');

  # or use this to actually create classes ...

  Class::MOP::Class->create('Bar' => (
      version      => '0.01',
      superclasses => [ 'Foo' ],
      attributes => [
          Class::MOP:::Attribute->new('$bar'),
          Class::MOP:::Attribute->new('$baz'),
      ],
      methods => {
          calculate_bar => sub { ... },
          construct_baz => sub { ... }
      }
  ));

=head1 DESCRIPTION

This is the largest and currently most complex part of the Perl 5
meta-object protocol. It controls the introspection and
manipulation of Perl 5 classes (and it can create them too). The
best way to understand what this module can do, is to read the
documentation for each of it's methods.

=head1 METHODS

=head2 Self Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related
to this class. Thereby allowing B<Class::MOP::Class> to actually
introspect itself.

As with B<Class::MOP::Attribute>, B<Class::MOP> will actually
bootstrap this module by installing a number of attribute meta-objects
into it's metaclass. This will allow this class to reap all the benifits
of the MOP when subclassing it.

=back

=head2 Class construction

These methods will handle creating B<Class::MOP::Class> objects,
which can be used to both create new classes, and analyze
pre-existing classes.

This module will internally store references to all the instances
you create with these methods, so that they do not need to be
created any more than nessecary. Basically, they are singletons.

=over 4

=item B<create ($package_name,
                version      =E<gt> ?$version,
                authority    =E<gt> ?$authority,
                superclasses =E<gt> ?@superclasses,
                methods      =E<gt> ?%methods,
                attributes   =E<gt> ?%attributes)>

This returns a B<Class::MOP::Class> object, bringing the specified
C<$package_name> into existence and adding any of the C<$version>,
C<$authority>, C<@superclasses>, C<%methods> and C<%attributes> to
it.

=item B<create_anon_class (superclasses =E<gt> ?@superclasses,
                           methods      =E<gt> ?%methods,
                           attributes   =E<gt> ?%attributes)>

This will create an anonymous class, it works much like C<create> but
it does not need a C<$package_name>. Instead it will create a suitably
unique package name for you to stash things into.

On very important distinction is that anon classes are destroyed once
the metaclass they are attached to goes out of scope. In the DESTROY
method, the created package will be removed from the symbol table.

It is also worth noting that any instances created with an anon-class
will keep a special reference to the anon-meta which will prevent the
anon-class from going out of scope until all instances of it have also
been destroyed. This however only works for HASH based instance types,
as we use a special reserved slot (C<__MOP__>) to store this.

=item B<initialize ($package_name, %options)>

This initializes and returns returns a B<Class::MOP::Class> object
for a given a C<$package_name>.

=item B<reinitialize ($package_name, %options)>

This removes the old metaclass, and creates a new one in it's place.
Do B<not> use this unless you really know what you are doing, it could
very easily make a very large mess of your program.

=item B<construct_class_instance (%options)>

This will construct an instance of B<Class::MOP::Class>, it is
here so that we can actually "tie the knot" for B<Class::MOP::Class>
to use C<construct_instance> once all the bootstrapping is done. This
method is used internally by C<initialize> and should never be called
from outside of that method really.

=item B<check_metaclass_compatability>

This method is called as the very last thing in the
C<construct_class_instance> method. This will check that the
metaclass you are creating is compatible with the metaclasses of all
your ancestors. For more inforamtion about metaclass compatibility
see the C<About Metaclass compatibility> section in L<Class::MOP>.

=item B<update_package_cache_flag>

This will reset the package cache flag for this particular metaclass
it is basically the value of the C<Class::MOP::get_package_cache_flag> 
function. This is very rarely needed from outside of C<Class::MOP::Class>
but in some cases you might want to use it, so it is here.

=item B<reset_package_cache_flag>

Clears the package cache flag to announce to the internals that we need 
to rebuild the method map.

=back

=head2 Object instance construction and cloning

These methods are B<entirely optional>, it is up to you whether you want
to use them or not.

=over 4

=item B<instance_metaclass>

Returns the class name of the instance metaclass, see L<Class::MOP::Instance> 
for more information on the instance metaclasses.

=item B<get_meta_instance>

Returns an instance of L<Class::MOP::Instance> to be used in the construction 
of a new instance of the class. 

=item B<new_object (%params)>

This is a convience method for creating a new object of the class, and
blessing it into the appropriate package as well. Ideally your class
would call a C<new> this method like so:

  sub MyClass::new {
      my ($class, %param) = @_;
      $class->meta->new_object(%params);
  }

=item B<construct_instance (%params)>

This method is used to construct an instance structure suitable for
C<bless>-ing into your package of choice. It works in conjunction
with the Attribute protocol to collect all applicable attributes.

This will construct and instance using a HASH ref as storage
(currently only HASH references are supported). This will collect all
the applicable attributes and layout out the fields in the HASH ref,
it will then initialize them using either use the corresponding key
in C<%params> or any default value or initializer found in the
attribute meta-object.

=item B<clone_object ($instance, %params)>

This is a convience method for cloning an object instance, then
blessing it into the appropriate package. This method will call
C<clone_instance>, which performs a shallow copy of the object,
see that methods documentation for more details. Ideally your
class would call a C<clone> this method like so:

  sub MyClass::clone {
      my ($self, %param) = @_;
      $self->meta->clone_object($self, %params);
  }

=item B<clone_instance($instance, %params)>

This method is a compliment of C<construct_instance> (which means if
you override C<construct_instance>, you need to override this one too),
and clones the instance shallowly.

The cloned structure returned is (like with C<construct_instance>) an
unC<bless>ed HASH reference, it is your responsibility to then bless
this cloned structure into the right class (which C<clone_object> will
do for you).

As of 0.11, this method will clone the C<$instance> structure shallowly,
as opposed to the deep cloning implemented in prior versions. After much
thought, research and discussion, I have decided that anything but basic
shallow cloning is outside the scope of the meta-object protocol. I
think Yuval "nothingmuch" Kogman put it best when he said that cloning
is too I<context-specific> to be part of the MOP.

=item B<rebless_instance($instance, ?%params)>

This will change the class of C<$instance> to the class of the invoking
C<Class::MOP::Class>. You may only rebless the instance to a subclass of
itself. You may pass in optional C<%params> which are like constructor 
params and will override anything already defined in the instance.

=back

=head2 Informational

These are a few predicate methods for asking information about the class.

=over 4

=item B<is_anon_class>

This returns true if the class is a C<Class::MOP::Class> created anon class.

=item B<is_mutable>

This returns true if the class is still mutable.

=item B<is_immutable>

This returns true if the class has been made immutable.

=back

=head2 Inheritance Relationships

=over 4

=item B<superclasses (?@superclasses)>

This is a read-write attribute which represents the superclass
relationships of the class the B<Class::MOP::Class> instance is
associated with. Basically, it can get and set the C<@ISA> for you.

=item B<class_precedence_list>

This computes the a list of all the class's ancestors in the same order
in which method dispatch will be done. This is similair to what 
B<Class::ISA::super_path> does, but we don't remove duplicate names.

=item B<linearized_isa>

This returns a list based on C<class_precedence_list> but with all 
duplicates removed.

=item B<subclasses>

This returns a list of subclasses for this class. 

=back

=head2 Methods

=over 4

=item B<get_method_map>

Returns a HASH ref of name to CODE reference mapping for this class.

=item B<method_metaclass>

Returns the class name of the method metaclass, see L<Class::MOP::Method> 
for more information on the method metaclasses.

=item B<add_method ($method_name, $method)>

This will take a C<$method_name> and CODE reference to that
C<$method> and install it into the class's package.

B<NOTE>:
This does absolutely nothing special to C<$method>
other than use B<Sub::Name> to make sure it is tagged with the
correct name, and therefore show up correctly in stack traces and
such.

=item B<alias_method ($method_name, $method)>

This will take a C<$method_name> and CODE reference to that
C<$method> and alias the method into the class's package.

B<NOTE>:
Unlike C<add_method>, this will B<not> try to name the
C<$method> using B<Sub::Name>, it only aliases the method in
the class's package.

=item B<has_method ($method_name)>

This just provides a simple way to check if the class implements
a specific C<$method_name>. It will I<not> however, attempt to check
if the class inherits the method (use C<UNIVERSAL::can> for that).

This will correctly handle functions defined outside of the package
that use a fully qualified name (C<sub Package::name { ... }>).

This will correctly handle functions renamed with B<Sub::Name> and
installed using the symbol tables. However, if you are naming the
subroutine outside of the package scope, you must use the fully
qualified name, including the package name, for C<has_method> to
correctly identify it.

This will attempt to correctly ignore functions imported from other
packages using B<Exporter>. It breaks down if the function imported
is an C<__ANON__> sub (such as with C<use constant>), which very well
may be a valid method being applied to the class.

In short, this method cannot always be trusted to determine if the
C<$method_name> is actually a method. However, it will DWIM about
90% of the time, so it's a small trade off I think.

=item B<get_method ($method_name)>

This will return a Class::MOP::Method instance related to the specified
C<$method_name>, or return undef if that method does not exist.

The Class::MOP::Method is codifiable, so you can use it like a normal
CODE reference, see L<Class::MOP::Method> for more information.

=item B<find_method_by_name ($method_name)>

This will return a CODE reference of the specified C<$method_name>,
or return undef if that method does not exist.

Unlike C<get_method> this will also look in the superclasses.

=item B<remove_method ($method_name)>

This will attempt to remove a given C<$method_name> from the class.
It will return the CODE reference that it has removed, and will
attempt to use B<Sub::Name> to clear the methods associated name.

=item B<get_method_list>

This will return a list of method names for all I<locally> defined
methods. It does B<not> provide a list of all applicable methods,
including any inherited ones. If you want a list of all applicable
methods, use the C<compute_all_applicable_methods> method.

=item B<compute_all_applicable_methods>

This will return a list of all the methods names this class will
respond to, taking into account inheritance. The list will be a list of
HASH references, each one containing the following information; method
name, the name of the class in which the method lives and a CODE
reference for the actual method.

=item B<find_all_methods_by_name ($method_name)>

This will traverse the inheritence hierarchy and locate all methods
with a given C<$method_name>. Similar to
C<compute_all_applicable_methods> it returns a list of HASH references
with the following information; method name (which will always be the
same as C<$method_name>), the name of the class in which the method
lives and a CODE reference for the actual method.

The list of methods produced is a distinct list, meaning there are no
duplicates in it. This is especially useful for things like object
initialization and destruction where you only want the method called
once, and in the correct order.

=item B<find_next_method_by_name ($method_name)>

This will return the first method to match a given C<$method_name> in
the superclasses, this is basically equivalent to calling
C<SUPER::$method_name>, but it can be dispatched at runtime.

=back

=head2 Method Modifiers

Method modifiers are a concept borrowed from CLOS, in which a method
can be wrapped with I<before>, I<after> and I<around> method modifiers
that will be called everytime the method is called.

=head3 How method modifiers work?

Method modifiers work by wrapping the original method and then replacing
it in the classes symbol table. The wrappers will handle calling all the
modifiers in the appropariate orders and preserving the calling context
for the original method.

Each method modifier serves a particular purpose, which may not be
obvious to users of other method wrapping modules. To start with, the
return values of I<before> and I<after> modifiers are ignored. This is
because thier purpose is B<not> to filter the input and output of the
primary method (this is done with an I<around> modifier). This may seem
like an odd restriction to some, but doing this allows for simple code
to be added at the begining or end of a method call without jeapordizing
the normal functioning of the primary method or placing any extra
responsibility on the code of the modifier. Of course if you have more
complex needs, then use the I<around> modifier, which uses a variation
of continutation passing style to allow for a high degree of flexibility.

Before and around modifiers are called in last-defined-first-called order,
while after modifiers are called in first-defined-first-called order. So
the call tree might looks something like this:

  before 2
   before 1
    around 2
     around 1
      primary
     after 1
    after 2

To see examples of using method modifiers, see the following examples
included in the distribution; F<InstanceCountingClass>, F<Perl6Attribute>,
F<AttributesWithHistory> and F<C3MethodDispatchOrder>. There is also a
classic CLOS usage example in the test F<017_add_method_modifier.t>.

=head3 What is the performance impact?

Of course there is a performance cost associated with method modifiers,
but we have made every effort to make that cost be directly proportional
to the amount of modifier features you utilize.

The wrapping method does it's best to B<only> do as much work as it
absolutely needs to. In order to do this we have moved some of the
performance costs to set-up time, where they are easier to amortize.

All this said, my benchmarks have indicated the following:

  simple wrapper with no modifiers             100% slower
  simple wrapper with simple before modifier   400% slower
  simple wrapper with simple after modifier    450% slower
  simple wrapper with simple around modifier   500-550% slower
  simple wrapper with all 3 modifiers          1100% slower

These numbers may seem daunting, but you must remember, every feature
comes with some cost. To put things in perspective, just doing a simple
C<AUTOLOAD> which does nothing but extract the name of the method called
and return it costs about 400% over a normal method call.

=over 4

=item B<add_before_method_modifier ($method_name, $code)>

This will wrap the method at C<$method_name> and the supplied C<$code>
will be passed the C<@_> arguments, and called before the original
method is called. As specified above, the return value of the I<before>
method modifiers is ignored, and it's ability to modify C<@_> is
fairly limited. If you need to do either of these things, use an
C<around> method modifier.

=item B<add_after_method_modifier ($method_name, $code)>

This will wrap the method at C<$method_name> so that the original
method will be called, it's return values stashed, and then the
supplied C<$code> will be passed the C<@_> arguments, and called.
As specified above, the return value of the I<after> method
modifiers is ignored, and it cannot modify the return values of
the original method. If you need to do either of these things, use an
C<around> method modifier.

=item B<add_around_method_modifier ($method_name, $code)>

This will wrap the method at C<$method_name> so that C<$code>
will be called and passed the original method as an extra argument
at the begining of the C<@_> argument list. This is a variation of
continuation passing style, where the function prepended to C<@_>
can be considered a continuation. It is up to C<$code> if it calls
the original method or not, there is no restriction on what the
C<$code> can or cannot do.

=back

=head2 Attributes

It should be noted that since there is no one consistent way to define
the attributes of a class in Perl 5. These methods can only work with
the information given, and can not easily discover information on
their own. See L<Class::MOP::Attribute> for more details.

=over 4

=item B<attribute_metaclass>

Returns the class name of the attribute metaclass, see L<Class::MOP::Attribute> 
for more information on the attribute metaclasses.

=item B<get_attribute_map>

This returns a HASH ref of name to attribute meta-object mapping.

=item B<add_attribute ($attribute_meta_object | ($attribute_name, %attribute_spec))>

This stores the C<$attribute_meta_object> (or creates one from the
C<$attribute_name> and C<%attribute_spec>) in the B<Class::MOP::Class>
instance associated with the given class. Unlike methods, attributes
within the MOP are stored as meta-information only. They will be used
later to construct instances from (see C<construct_instance> above).
More details about the attribute meta-objects can be found in the
L<Class::MOP::Attribute> or the L<Class::MOP/The Attribute protocol>
section.

It should be noted that any accessor, reader/writer or predicate
methods which the C<$attribute_meta_object> has will be installed
into the class at this time.

B<NOTE>
If an attribute already exists for C<$attribute_name>, the old one
will be removed (as well as removing all it's accessors), and then
the new one added.

=item B<has_attribute ($attribute_name)>

Checks to see if this class has an attribute by the name of
C<$attribute_name> and returns a boolean.

=item B<get_attribute ($attribute_name)>

Returns the attribute meta-object associated with C<$attribute_name>,
if none is found, it will return undef.

=item B<remove_attribute ($attribute_name)>

This will remove the attribute meta-object stored at
C<$attribute_name>, then return the removed attribute meta-object.

B<NOTE:>
Removing an attribute will only affect future instances of
the class, it will not make any attempt to remove the attribute from
any existing instances of the class.

It should be noted that any accessor, reader/writer or predicate
methods which the attribute meta-object stored at C<$attribute_name>
has will be removed from the class at this time. This B<will> make
these attributes somewhat inaccessable in previously created
instances. But if you are crazy enough to do this at runtime, then
you are crazy enough to deal with something like this :).

=item B<get_attribute_list>

This returns a list of attribute names which are defined in the local
class. If you want a list of all applicable attributes for a class,
use the C<compute_all_applicable_attributes> method.

=item B<compute_all_applicable_attributes>

This will traverse the inheritance heirachy and return a list of all
the applicable attributes for this class. It does not construct a
HASH reference like C<compute_all_applicable_methods> because all
that same information is discoverable through the attribute
meta-object itself.

=item B<find_attribute_by_name ($attr_name)>

This method will traverse the inheritance heirachy and find the
first attribute whose name matches C<$attr_name>, then return it.
It will return undef if nothing is found.

=back

=head2 Class Immutability

=over 4

=item B<make_immutable (%options)>

This method will invoke a tranforamtion upon the class which will
make it immutable. Details of this transformation can be found in
the L<Class::MOP::Immutable> documentation.

=item B<make_mutable>

This method will reverse tranforamtion upon the class which
made it immutable.

=item B<get_immutable_transformer>

Return a transformer suitable for making this class immutable or, if this
class is immutable, the transformer used to make it immutable.

=item B<get_immutable_options>

If the class is immutable, return the options used to make it immutable.

=item B<create_immutable_transformer>

Create a transformer suitable for making this class immutable

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2008 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
