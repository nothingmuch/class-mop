
package Class::MOP::Class;

use strict;
use warnings;

use Class::MOP::Immutable;
use Class::MOP::Instance;
use Class::MOP::Method::Wrapped;

use Carp         'confess';
use Scalar::Util 'blessed', 'weaken';

our $VERSION   = '0.78_02';
$VERSION = eval $VERSION;
our $AUTHORITY = 'cpan:STEVAN';

use base 'Class::MOP::Module';

# Creation

sub initialize {
    my $class = shift;

    my $package_name;
    
    if ( @_ % 2 ) {
        $package_name = shift;
    } else {
        my %options = @_;
        $package_name = $options{package};
    }

    (defined $package_name && $package_name && !ref($package_name))
        || confess "You must pass a package name and it cannot be blessed";

    return Class::MOP::get_metaclass_by_name($package_name)
        || $class->construct_class_instance(package => $package_name, @_);
}

# NOTE: (meta-circularity)
# this is a special form of &construct_instance
# (see below), which is used to construct class
# meta-object instances for any Class::MOP::*
# class. All other classes will use the more
# normal &construct_instance.
sub construct_class_instance {
    my $class        = shift;
    my $options      = @_ == 1 ? $_[0] : {@_};
    my $package_name = $options->{package};
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
    $class = (ref($class)
                    ? ($class->is_immutable
                        ? $class->get_mutable_metaclass_name()
                        : ref($class))
                    : $class);

    # now create the metaclass
    my $meta;
    if ($class eq 'Class::MOP::Class') {
        $meta = $class->_new($options);
    }
    else {
        # NOTE:
        # it is safe to use meta here because
        # class will always be a subclass of
        # Class::MOP::Class, which defines meta
        $meta = $class->meta->construct_instance($options)
    }

    # and check the metaclass compatibility
    $meta->check_metaclass_compatibility();  

    Class::MOP::store_metaclass_by_name($package_name, $meta);

    # NOTE:
    # we need to weaken any anon classes
    # so that they can call DESTROY properly
    Class::MOP::weaken_metaclass($package_name) if $meta->is_anon_class;

    $meta;
}

sub _new {
    my $class = shift;
    my $options = @_ == 1 ? $_[0] : {@_};

    bless {
        # inherited from Class::MOP::Package
        'package' => $options->{package},

        # NOTE:
        # since the following attributes will
        # actually be loaded from the symbol
        # table, and actually bypass the instance
        # entirely, we can just leave these things
        # listed here for reference, because they
        # should not actually have a value associated
        # with the slot.
        'namespace' => \undef,

        # inherited from Class::MOP::Module
        'version'   => \undef,
        'authority' => \undef,

        # defined in Class::MOP::Class
        'superclasses' => \undef,

        'methods'             => {},
        'attributes'          => {},
        'attribute_metaclass' => $options->{'attribute_metaclass'}
            || 'Class::MOP::Attribute',
        'method_metaclass' => $options->{'method_metaclass'}
            || 'Class::MOP::Method',
        'wrapped_method_metaclass' => $options->{'wrapped_method_metaclass'}
            || 'Class::MOP::Method::Wrapped',
        'instance_metaclass' => $options->{'instance_metaclass'}
            || 'Class::MOP::Instance',
    }, $class;
}

sub reset_package_cache_flag  { (shift)->{'_package_cache_flag'} = undef } 
sub update_package_cache_flag {
    my $self = shift;
    # NOTE:
    # we can manually update the cache number 
    # since we are actually adding the method
    # to our cache as well. This avoids us 
    # having to regenerate the method_map.
    # - SL    
    $self->{'_package_cache_flag'} = Class::MOP::check_package_cache_flag($self->name);    
}

sub check_metaclass_compatibility {
    my $self = shift;

    # this is always okay ...
    return if ref($self)                eq 'Class::MOP::Class'   &&
              $self->instance_metaclass eq 'Class::MOP::Instance';

    my @class_list = $self->linearized_isa;
    shift @class_list; # shift off $self->name

    foreach my $superclass_name (@class_list) {
        my $super_meta = Class::MOP::get_metaclass_by_name($superclass_name) || next;

        # NOTE:
        # we need to deal with the possibility
        # of class immutability here, and then
        # get the name of the class appropriately
        my $super_meta_type
            = $super_meta->is_immutable
            ? $super_meta->get_mutable_metaclass_name()
            : ref($super_meta);

        ($self->isa($super_meta_type))
            || confess $self->name . "->meta => (" . (ref($self)) . ")" .
                       " is not compatible with the " .
                       $superclass_name . "->meta => (" . ($super_meta_type)     . ")";
        # NOTE:
        # we also need to check that instance metaclasses
        # are compatibile in the same the class.
        ($self->instance_metaclass->isa($super_meta->instance_metaclass))
            || confess $self->name . "->meta->instance_metaclass => (" . ($self->instance_metaclass) . ")" .
                       " is not compatible with the " .
                       $superclass_name . "->meta->instance_metaclass => (" . ($super_meta->instance_metaclass) . ")";
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
        $self->name =~ /^$ANON_CLASS_PREFIX/;
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

        return if Class::MOP::in_global_destruction(); # it'll happen soon anyway and this just makes things more complicated

        no warnings 'uninitialized';
        return unless $self->name =~ /^$ANON_CLASS_PREFIX/;
        # Moose does a weird thing where it replaces the metaclass for
        # class when fixing metaclass incompatibility. In that case,
        # we don't want to clean out the namespace now. We can detect
        # that because Moose will explicitly update the singleton
        # cache in Class::MOP.
        my $current_meta = Class::MOP::get_metaclass_by_name($self->name);
        return if $current_meta ne $self;

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
    my ( $class, @args ) = @_;

    unshift @args, 'package' if @args % 2 == 1;

    my (%options) = @args;
    my $package_name = $options{package};

    (ref $options{superclasses} eq 'ARRAY')
        || confess "You must pass an ARRAY ref of superclasses"
            if exists $options{superclasses};
            
    (ref $options{attributes} eq 'ARRAY')
        || confess "You must pass an ARRAY ref of attributes"
            if exists $options{attributes};      
            
    (ref $options{methods} eq 'HASH')
        || confess "You must pass a HASH ref of methods"
            if exists $options{methods};                  

    $class->SUPER::create(%options);

    my (%initialize_options) = @args;
    delete @initialize_options{qw(
        package
        superclasses
        attributes
        methods
        version
        authority
    )};
    my $meta = $class->initialize( $package_name => %initialize_options );

    # FIXME totally lame
    $meta->add_method('meta' => sub {
        $class->initialize(ref($_[0]) || $_[0]);
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

sub get_attribute_map        { $_[0]->{'attributes'}                  }
sub attribute_metaclass      { $_[0]->{'attribute_metaclass'}         }
sub method_metaclass         { $_[0]->{'method_metaclass'}            }
sub wrapped_method_metaclass { $_[0]->{'wrapped_method_metaclass'}    }
sub instance_metaclass       { $_[0]->{'instance_metaclass'}          }

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
    my $class = shift;
    my $params = @_ == 1 ? $_[0] : {@_};
    my $meta_instance = $class->get_meta_instance();
    my $instance = $meta_instance->create_instance();
    foreach my $attr ($class->compute_all_applicable_attributes()) {
        $attr->initialize_instance_slot($meta_instance, $instance, $params);
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
    $self->{'_meta_instance'} ||= $self->create_meta_instance();
}

sub create_meta_instance {
    my $self = shift;
    
    my $instance = $self->instance_metaclass->new(
        associated_metaclass => $self,
        attributes => [ $self->compute_all_applicable_attributes() ],
    );

    $self->add_meta_instance_dependencies()
        if $instance->is_dependent_on_superclasses();

    return $instance;
}

sub clone_object {
    my $class    = shift;
    my $instance = shift;
    (blessed($instance) && $instance->isa($class->name))
        || confess "You must pass an instance of the metaclass (" . (ref $class ? $class->name : $class) . "), not ($instance)";

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

    $old_metaclass->rebless_instance_away($instance, $self, %params);

    my $meta_instance = $self->get_meta_instance();

    $self->name->isa($old_metaclass->name)
        || confess "You may rebless only into a subclass of (". $old_metaclass->name ."), of which (". $self->name .") isn't.";

    # rebless!
    # we use $_[1] here because of t/306_rebless_overload.t regressions on 5.8.8
    $meta_instance->rebless_instance_structure($_[1], $self);

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

sub rebless_instance_away {
    # this intentionally does nothing, it is just a hook
}

# Inheritance

sub superclasses {
    my $self     = shift;
    my $var_spec = { sigil => '@', type => 'ARRAY', name => 'ISA' };
    if (@_) {
        my @supers = @_;
        @{$self->get_package_symbol($var_spec)} = @supers;

        # NOTE:
        # on 5.8 and below, we need to call
        # a method to get Perl to detect
        # a cycle in the class hierarchy
        my $class = $self->name;
        $class->isa($class);

        # NOTE:
        # we need to check the metaclass
        # compatibility here so that we can
        # be sure that the superclass is
        # not potentially creating an issues
        # we don't know about

        $self->check_metaclass_compatibility();
        $self->update_meta_instance_dependencies();
    }
    @{$self->get_package_symbol($var_spec)};
}

sub subclasses {
    my $self = shift;

    my $super_class = $self->name;

    if ( Class::MOP::HAVE_ISAREV() ) {
        return @{ $super_class->mro::get_isarev() };
    } else {
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
                name         => $method_name            
            ) if $method->can('clone');
        }
    }
    else {
        $body = $method;
        $method = $self->wrap_method_body( body => $body, name => $method_name );
    }

    $method->attach_to_class($self);

    # This used to call get_method_map, which meant we would build all
    # the method objects for the class just because we added one
    # method. This is hackier, but quicker too.
    $self->{methods}{$method_name} = $method;
    
    my $full_method_name = ($self->name . '::' . $method_name);    
    $self->add_package_symbol(
        { sigil => '&', type => 'CODE', name => $method_name }, 
        Class::MOP::subname($full_method_name => $body)
    );
}

{
    my $fetch_and_prepare_method = sub {
        my ($self, $method_name) = @_;
        my $wrapped_metaclass = $self->wrapped_method_metaclass;
        # fetch it locally
        my $method = $self->get_method($method_name);
        # if we dont have local ...
        unless ($method) {
            # try to find the next method
            $method = $self->find_next_method_by_name($method_name);
            # die if it does not exist
            (defined $method)
                || confess "The method '$method_name' was not found in the inheritance hierarchy for " . $self->name;
            # and now make sure to wrap it
            # even if it is already wrapped
            # because we need a new sub ref
            $method = $wrapped_metaclass->wrap($method);
        }
        else {
            # now make sure we wrap it properly
            $method = $wrapped_metaclass->wrap($method)
                unless $method->isa($wrapped_metaclass);
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
    my $self = shift;

    $self->add_method(@_);
}

sub has_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    exists $self->{methods}{$method_name} || exists $self->get_method_map->{$method_name};
}

sub get_method {
    my ($self, $method_name) = @_;
    (defined $method_name && $method_name)
        || confess "You must define a method name";

    return $self->{methods}{$method_name} || $self->get_method_map->{$method_name};
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

sub get_all_methods {
    my $self = shift;
    my %methods = map { %{ $self->initialize($_)->get_method_map } } reverse $self->linearized_isa;
    return values %methods;
}

# compatibility
sub compute_all_applicable_methods {
    return map {
        {
            name  => $_->name,
            class => $_->package_name,
            code  => $_, # sigh, overloading
        },
    } shift->get_all_methods(@_);
}

sub get_all_method_names {
    my $self = shift;
    my %uniq;
    grep { $uniq{$_}++ == 0 } map { $_->name } $self->get_all_methods;
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
    if ( $self->has_attribute($attribute->name) ) {
        $self->remove_attribute($attribute->name);
    } else {
        $self->invalidate_meta_instances();
    }

    # then onto installing the new accessors
    $self->get_attribute_map->{$attribute->name} = $attribute;

    # invalidate package flag here
    my $e = do { local $@; eval { $attribute->install_accessors() }; $@ };
    if ( $e ) {
        $self->remove_attribute($attribute->name);
        die $e;
    }

    return $attribute;
}

sub update_meta_instance_dependencies {
    my $self = shift;

    if ( $self->{meta_instance_dependencies} ) {
        return $self->add_meta_instance_dependencies;
    }
}

sub add_meta_instance_dependencies {
    my $self = shift;

    $self->remove_meta_instance_dependencies;

    my @attrs = $self->compute_all_applicable_attributes();

    my %seen;
    my @classes = grep { not $seen{$_->name}++ } map { $_->associated_class } @attrs;

    foreach my $class ( @classes ) { 
        $class->add_dependent_meta_instance($self);
    }

    $self->{meta_instance_dependencies} = \@classes;
}

sub remove_meta_instance_dependencies {
    my $self = shift;

    if ( my $classes = delete $self->{meta_instance_dependencies} ) {
        foreach my $class ( @$classes ) {
            $class->remove_dependent_meta_instance($self);
        }

        return $classes;
    }

    return;

}

sub add_dependent_meta_instance {
    my ( $self, $metaclass ) = @_;
    push @{ $self->{dependent_meta_instances} }, $metaclass;
}

sub remove_dependent_meta_instance {
    my ( $self, $metaclass ) = @_;
    my $name = $metaclass->name;
    @$_ = grep { $_->name ne $name } @$_ for $self->{dependent_meta_instances};
}

sub invalidate_meta_instances {
    my $self = shift;
    $_->invalidate_meta_instance() for $self, @{ $self->{dependent_meta_instances} };
}

sub invalidate_meta_instance {
    my $self = shift;
    undef $self->{_meta_instance};
}

sub has_attribute {
    my ($self, $attribute_name) = @_;
    (defined $attribute_name && $attribute_name)
        || confess "You must define an attribute name";
    exists $self->get_attribute_map->{$attribute_name};
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
    $self->invalidate_meta_instances();
    $removed_attribute->remove_accessors();
    $removed_attribute->detach_from_class();
    return $removed_attribute;
}

sub get_attribute_list {
    my $self = shift;
    keys %{$self->get_attribute_map};
}

sub get_all_attributes {
    shift->compute_all_applicable_attributes(@_);
}

sub compute_all_applicable_attributes {
    my $self = shift;
    my %attrs = map { %{ $self->initialize($_)->get_attribute_map } } reverse $self->linearized_isa;
    return values %attrs;
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

# check if we can reinitialize
sub is_pristine {
    my $self = shift;

    # if any local attr is defined
    return if $self->get_attribute_list;

    # or any non-declared methods
    if ( my @methods = values %{ $self->get_method_map } ) {
        my $metaclass = $self->method_metaclass;
        foreach my $method ( @methods ) {
            return if $method->isa("Class::MOP::Method::Generated");
            # FIXME do we need to enforce this too? return unless $method->isa($metaclass);
        }
    }

    return 1;
}

## Class closing

sub is_mutable   { 1 }
sub is_immutable { 0 }

sub immutable_transformer { $_[0]->{immutable_transformer} }
sub _set_immutable_transformer { $_[0]->{immutable_transformer} = $_[1] }

sub make_immutable {
    my $self = shift;

    return if $self->is_immutable;

    my $transformer = $self->immutable_transformer
        || $self->_make_immutable_transformer(@_);

    $self->_set_immutable_transformer($transformer);

    $transformer->make_metaclass_immutable;
}

{
    my %Default_Immutable_Options = (
        read_only   => [qw/superclasses/],
        cannot_call => [
            qw(
                add_method
                alias_method
                remove_method
                add_attribute
                remove_attribute
                remove_package_symbol
                )
        ],
        memoize => {
            class_precedence_list => 'ARRAY',
            # FIXME perl 5.10 memoizes this on its own, no need?
            linearized_isa                    => 'ARRAY',
            get_all_methods                   => 'ARRAY',
            get_all_method_names              => 'ARRAY',
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
                    unless ( caller(2) )[3] eq
                    'Class::MOP::Package::get_package_symbol';

                # This is a workaround for a bug in 5.8.1 which thinks that
                # goto $original->body
                # is trying to go to a label
                my $body = $original->body;
                goto $body;
            },
        },
    );

    sub _default_immutable_transformer_options {
        return %Default_Immutable_Options;
    }
}

sub _make_immutable_transformer {
    my $self = shift;

    Class::MOP::Immutable->new(
        $self,
        $self->_default_immutable_transformer_options,
        @_
    );
}

sub make_mutable {
    my $self = shift;

    return if $self->is_mutable;

    $self->immutable_transformer->make_metaclass_mutable;
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
  Foo->meta->add_method( 'bar' => sub {...} )

      # get a list of all the classes searched
      # the method dispatcher in the correct order
      Foo->meta->class_precedence_list()

      # remove a method from Foo
      Foo->meta->remove_method('bar');

  # or use this to actually create classes ...

  Class::MOP::Class->create(
      'Bar' => (
          version      => '0.01',
          superclasses => ['Foo'],
          attributes   => [
              Class::MOP:: : Attribute->new('$bar'),
              Class::MOP:: : Attribute->new('$baz'),
          ],
          methods => {
              calculate_bar => sub {...},
              construct_baz => sub {...}
          }
      )
  );

=head1 DESCRIPTION

The Class Protocol is the largest and most complex part of the
Class::MOP meta-object protocol. It controls the introspection and
manipulation of Perl 5 classes, and it can create them as well. The
best way to understand what this module can do, is to read the
documentation for each of its methods.

=head1 INHERITANCE

C<Class::MOP::Class> is a subclass of L<Class::MOP::Module>.

=head1 METHODS

=head2 Class construction

These methods all create new C<Class::MOP::Class> objects. These
objects can represent existing classes, or they can be used to create
new classes from scratch.

The metaclass object for a given class is a singleton. If you attempt
to create a metaclass for the same class twice, you will just get the
existing object.

=over 4

=item B<< Class::MOP::Class->create($package_name, %options) >>

This method creates a new C<Class::MOP::Class> object with the given
package name. It accepts a number of options.

=over 8

=item * version

An optional version number for the newly created package.

=item * authority

An optional authority for the newly created package.

=item * superclasses

An optional array reference of superclass names.

=item * methods

An optional hash reference of methods for the class. The keys of the
hash reference are method names, and values are subroutine references.

=item * attributes

An optional array reference of attributes.

An attribute can be passed as an existing L<Class::MOP::Attribute>
object, I<or> or as a hash reference of options which will be passed
to the attribute metaclass's constructor.

=back

=item B<< Class::MOP::Class->create_anon_class(%options) >>

This method works just like C<< Class::MOP::Class->create >> but it
creates an "anonymous" class. In fact, the class does have a name, but
that name is a unique name generated internally by this module.

It accepts the same C<superclasses>, C<methods>, and C<attributes>
parameters that C<create> accepts.

Anonymous classes are destroyed once the metaclass they are attached
to goes out of scope, and will be removed from Perl's internal symbol
table.

All instances of an anonymous class keep a special reference to the
metaclass object, which prevents the metaclass from going out of scope
while any instances exist.

This only works if the instance if based on a hash reference, however.

=item B<< Class::MOP::Class->initialize($package_name, %options) >>

This method will initialize a C<Class::MOP::Class> object for the
named package. Unlike C<create>, this method I<will not> create a new
class.

The purpose of this method is to retrieve a C<Class::MOP::Class>
object for introspecting an existing class.

If an existing C<Class::MOP::Class> object exists for the named
package, it will be returned, and any options provided will be
ignored!

If the object does not yet exist, it will be created.

The valid options that can be passed to this method are
C<attribute_metaclass>, C<method_metaclass>,
C<wrapped_method_metaclass>, and C<instance_metaclass>. These are all
optional, and default to the appropriate class in the C<Class::MOP>
distribution.

=back

=head2 Object instance construction and cloning

These methods are all related to creating and/or cloning object
instances.

=over 4

=item B<< $metaclass->clone_object($instance, %params) >>

This method clones an existing object instance. Any parameters you
provide are will override existing attribute values in the object.

This is a convenience method for cloning an object instance, then
blessing it into the appropriate package.

You could implement a clone method in your class, using this method:

  sub clone {
      my ($self, %params) = @_;
      $self->meta->clone_object($self, %params);
  }

=item B<< $metaclass->rebless_instance($instance, %params) >>

This method changes the class of C<$instance> to the metaclass's class.

You can only rebless an instance into a subclass of its current
class. If you pass any additional parameters, these will be treated
like constructor parameters and used to initialize the object's
attributes. Any existing attributes that are already set will be
overwritten.

Before reblessing the instance, this method will call
C<rebless_instance_away> on the instance's current metaclass. This method
will be passed the instance, the new metaclass, and any parameters
specified to C<rebless_instance>. By default, C<rebless_instance_away>
does nothing; it is merely a hook.

=item B<< $metaclass->new_object(%params) >>

This method is used to create a new object of the metaclass's
class. Any parameters you provide are used to initialize the
instance's attributes.

=item B<< $metaclass->instance_metaclass >>

Returns the class name of the instance metaclass, see
L<Class::MOP::Instance> for more information on the instance
metaclass.

=item B<< $metaclass->get_meta_instance >>

Returns an instance of the C<instance_metaclass> to be used in the
construction of a new instance of the class.

=back

=head2 Informational predicates

These are a few predicate methods for asking information about the
class itself.

=over 4

=item B<< $metaclass->is_anon_class >>

This returns true if the class was created by calling C<<
Class::MOP::Class->create_anon_class >>.

=item B<< $metaclass->is_mutable >>

This returns true if the class is still mutable.

=item B<< $metaclass->is_immutable >>

This returns true if the class has been made immutable.

=item B<< $metaclass->is_pristine >>

A class is I<not> pristine if it has non-inherited attributes or if it
has any generated methods.

=back

=head2 Inheritance Relationships

=over 4

=item B<< $metaclass->superclasses(@superclasses) >>

This is a read-write accessor which represents the superclass
relationships of the metaclass's class.

This is basically sugar around getting and setting C<@ISA>.

=item B<< $metaclass->class_precedence_list >>

This returns a list of all of the class's ancestor classes. The
classes are returned in method dispatch order.

=item B<< $metaclass->linearized_isa >>

This returns a list based on C<class_precedence_list> but with all
duplicates removed.

=item B<< $metaclass->subclasses >>

This returns a list of subclasses for this class.

=back

=head2 Method introspection and creation

These methods allow you to introspect a class's methods, as well as
add, remove, or change methods.

Determining what is truly a method in a Perl 5 class requires some
heuristics (aka guessing).

Methods defined outside the package with a fully qualified name (C<sub
Package::name { ... }>) will be included. Similarly, methods named
with a fully qualified name using L<Sub::Name> are also included.

However, we attempt to ignore imported functions.

Ultimately, we are using heuristics to determine what truly is a
method in a class, and these heuristics may get the wrong answer in
some edge cases. However, for most "normal" cases the heuristics work
correctly.

=over 4

=item B<< $metaclass->get_method($method_name) >>

This will return a L<Class::MOP::Method> for the specified
C<$method_name>. If the class does not have the specified method, it
returns C<undef>

=item B<< $metaclass->has_method($method_name) >>

Returns a boolean indicating whether or not the class defines the
named method. It does not include methods inherited from parent
classes.

=item B<< $metaclass->get_method_map >>

Returns a hash reference representing the methods defined in this
class. The keys are method names and the values are
L<Class::MOP::Method> objects.

=item B<< $metaclass->get_method_list >>

This will return a list of method I<names> for all methods defined in
this class.

=item B<< $metaclass->get_all_methods >>

This will traverse the inheritance hierarchy and return a list of all
the L<Class::MOP::Method> objects for this class and its parents.

=item B<< $metaclass->find_method_by_name($method_name) >>

This will return a L<Class::MOP::Method> for the specified
C<$method_name>. If the class does not have the specified method, it
returns C<undef>

Unlike C<get_method>, this method I<will> look for the named method in
superclasses.

=item B<< $metaclass->get_all_method_names >>

This will return a list of method I<names> for all of this class's
methods, including inherited methods.

=item B<< $metaclass->find_all_methods_by_name($method_name) >>

This method looks for the named method in the class and all of its
parents. It returns every matching method it finds in the inheritance
tree, so it returns a list of methods.

Each method is returned as a hash reference with three keys. The keys
are C<name>, C<class>, and C<code>. The C<code> key has a
L<Class::MOP::Method> object as its value.

The list of methods is distinct.

=item B<< $metaclass->find_next_method_by_name($method_name) >>

This method returns the first method in any superclass matching the
given name. It is effectively the method that C<SUPER::$method_name>
would dispatch to.

=item B<< $metaclass->add_method($method_name, $method) >>

This method takes a method name and a subroutine reference, and adds
the method to the class.

The subroutine reference can be a L<Class::MOP::Method>, and you are
strongly encouraged to pass a meta method object instead of a code
reference. If you do so, that object gets stored as part of the
class's method map directly. If not, the meta information will have to
be recreated later, and may be incorrect.

If you provide a method object, this method will clone that object if
the object's package name does not match the class name. This lets us
track the original source of any methods added from other classes
(notably Moose roles).

=item B<< $metaclass->remove_method($method_name) >>

Remove the named method from the class. This method returns the
L<Class::MOP::Method> object for the method.

=item B<< $metaclass->method_metaclass >>

Returns the class name of the method metaclass, see
L<Class::MOP::Method> for more information on the method metaclass.

=item B<< $metaclass->wrapped_method_metaclass >>

Returns the class name of the wrapped method metaclass, see
L<Class::MOP::Method::Wrapped> for more information on the wrapped
method metaclass.

=back

=head2 Attribute introspection and creation

Because Perl 5 does not have a core concept of attributes in classes,
we can only return information about attributes which have been added
via this class's methods. We cannot discover information about
attributes which are defined in terms of "regular" Perl 5 methods.

=over 4

=item B<< $metaclass->get_attribute($attribute_name) >>

This will return a L<Class::MOP::Attribute> for the specified
C<$attribute_name>. If the class does not have the specified
attribute, it returns C<undef>

=item B<< $metaclass->has_attribute($attribute_name) >>

Returns a boolean indicating whether or not the class defines the
named attribute. It does not include attributes inherited from parent
classes.

=item B<< $metaclass->get_attribute_map >>

Returns a hash reference representing the attributes defined in this
class. The keys are attribute names and the values are
L<Class::MOP::Attribute> objects.

=item B<< $metaclass->get_attribute_list >>

This will return a list of attributes I<names> for all attributes
defined in this class.

=item B<< $metaclass->get_all_attributes >>

This will traverse the inheritance hierarchy and return a list of all
the L<Class::MOP::Attribute> objects for this class and its parents.

This method can also be called as C<compute_all_applicable_attributes>.

=item B<< $metaclass->find_attribute_by_name($attribute_name) >>

This will return a L<Class::MOP::Attribute> for the specified
C<$attribute_name>. If the class does not have the specified
attribute, it returns C<undef>

Unlike C<get_attribute>, this attribute I<will> look for the named
attribute in superclasses.

=item B<< $metaclass->add_attribute(...) >>

This method accepts either an existing L<Class::MOP::Attribute>
object, or parameters suitable for passing to that class's C<new>
method.

The attribute provided will be added to the class.

Any accessor methods defined by the attribute will be added to the
class when the attribute is added.

If an attribute of the same name already exists, the old attribute
will be removed first.

=item B<< $metaclass->remove_attribute($attribute_name) >>

This will remove the named attribute from the class, and
L<Class::MOP::Attribute> object.

Removing an attribute also removes any accessor methods defined by the
attribute.

However, note that removing an attribute will only affect I<future>
object instances created for this class, not existing instances.

=item B<< $metaclass->attribute_metaclass >>

Returns the class name of the attribute metaclass for this class. By
default, this is L<Class::MOP::Attribute>.  for more information on

=back

=head2 Class Immutability

Making a class immutable "freezes" the class definition. You can no
longer call methods which alter the class, such as adding or removing
methods or attributes.

Making a class immutable lets us optimize the class by inlining some
methods, and also allows us to optimize some methods on the metaclass
object itself.

The immutabilization system in L<Moose> takes much greater advantage
of the inlining features than Class::MOP itself does.

=over 4

=item B<< $metaclass->make_immutable(%options) >>

This method will create an immutable transformer and uses it to make
the class and its metaclass object immutable.

Details of how immutabilization works are in L<Class::MOP::Immutable>
documentation.

=item B<< $metaclass->make_mutable >>

Calling this method reverse the immutabilization transformation.

=item B<< $metaclass->immutable_transformer >>

If the class has been made immutable previously, this returns the
L<Class::MOP::Immutable> object that was created to do the
transformation.

If the class was never made immutable, this method will die.

=back

=head2 Method Modifiers

Method modifiers are hooks which allow a method to be wrapped with
I<before>, I<after> and I<around> method modifiers. Every time a
method is called, it's modifiers are also called.

A class can modify its own methods, as well as methods defined in
parent classes.

=head3 How method modifiers work?

Method modifiers work by wrapping the original method and then
replacing it in the class's symbol table. The wrappers will handle
calling all the modifiers in the appropriate order and preserving the
calling context for the original method.

The return values of C<before> and C<after> modifiers are
ignored. This is because their purpose is B<not> to filter the input
and output of the primary method (this is done with an I<around>
modifier).

This may seem like an odd restriction to some, but doing this allows
for simple code to be added at the beginning or end of a method call
without altering the function of the wrapped method or placing any
extra responsibility on the code of the modifier.

Of course if you have more complex needs, you can use the C<around>
modifier which allows you to change both the parameters passed to the
wrapped method, as well as its return value.

Before and around modifiers are called in last-defined-first-called
order, while after modifiers are called in first-defined-first-called
order. So the call tree might looks something like this:

  before 2
   before 1
    around 2
     around 1
      primary
     around 1
    around 2
   after 1
  after 2

=head3 What is the performance impact?

Of course there is a performance cost associated with method
modifiers, but we have made every effort to make that cost directly
proportional to the number of modifier features you utilize.

The wrapping method does it's best to B<only> do as much work as it
absolutely needs to. In order to do this we have moved some of the
performance costs to set-up time, where they are easier to amortize.

All this said, our benchmarks have indicated the following:

  simple wrapper with no modifiers             100% slower
  simple wrapper with simple before modifier   400% slower
  simple wrapper with simple after modifier    450% slower
  simple wrapper with simple around modifier   500-550% slower
  simple wrapper with all 3 modifiers          1100% slower

These numbers may seem daunting, but you must remember, every feature
comes with some cost. To put things in perspective, just doing a
simple C<AUTOLOAD> which does nothing but extract the name of the
method called and return it costs about 400% over a normal method
call.

=over 4

=item B<< $metaclass->add_before_method_modifier($method_name, $code) >>

This wraps the specified method with the supplied subroutine
reference. The modifier will be called as a method itself, and will
receive the same arguments as are passed to the method.

When the modifier exits, the wrapped method will be called.

The return value of the modifier will be ignored.

=item B<< $metaclass->add_after_method_modifier($method_name, $code) >>

This wraps the specified method with the supplied subroutine
reference. The modifier will be called as a method itself, and will
receive the same arguments as are passed to the method.

When the wrapped methods exits, the modifier will be called.

The return value of the modifier will be ignored.

=item B<< $metaclass->add_around_method_modifier($method_name, $code) >>

This wraps the specified method with the supplied subroutine
reference.

The first argument passed to the modifier will be a subroutine
reference to the wrapped method. The second argument is the object,
and after that come any arguments passed when the method is called.

The around modifier can choose to call the original method, as well as
what arguments to pass if it does so.

The return value of the modifier is what will be seen by the caller.

=back

=head2 Introspection

=over 4

=item B<< Class::MOP::Class->meta >>

This will return a L<Class::MOP::Class> instance for this class.

It should also be noted that L<Class::MOP> will actually bootstrap
this module by installing a number of attribute meta-objects into its
metaclass.

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
