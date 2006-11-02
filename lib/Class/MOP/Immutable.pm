
package Class::MOP::Immutable;

1;

__END__

=pod

Okay, so here is the basic idea.

First, your metaclass must register with Class::MOP::Immutable
at which point an anon-class is created which will be the 
immutable class which your metaclass will be blessed into. 

This allows immutable versions of any metaclass to be created
on the fly if needed. 

NOTE:
Remember the immutable version of the metaclass will be used to 
construct/convert mutable instances into immutable versions. So 
it itself is a metaclass.

  Class::MOP::Immutable->make_immutable_metaclass(
      # name of the metaclass we are 
      # making immutable
      metaclass => 'Class::MOP::Class',
      
      # names of some method metaclasses
      # which will be useful in the creation
      # of the immutable versions
      constructor_class => 'Class::MOP::Method::Constructor',
      accessor_class    => 'Class::MOP::Method::Accessor',    # ?? maybe
      
      # options which the immutable converter
      # will accept, not exactly sure about 
      # this one,.. it might have to be hard 
      # coded in some way.
      available_options => [qw[
          inline_accessors
          inline_constructor
          constructor_name
      ]],    
      
      # multiple lists of things which can 
      # be done to the metaclass .. 
      
      # make these methods die when called
      disallow  => [qw[
          add_method
          alias_method
          remove_method
          add_attribute
          remove_attribute
          add_package_symbol
          remove_package_symbol
      ]],
      
      # memoize the value of these methods
      memoize   => [qw[
          class_precedence_list
          compute_all_applicable_attributes
          get_meta_instance            
          get_method_map
      ]],
      
      # make these methods read only
      readonly  => [qw[
          superclasses
      ]],
  );

Now, this will work just fine for singular metas, but 
we want this to be able to work for extensions to the 
metaclasses as well.

Here is how we do that:

  Class::MOP::Immutable->make_immutable_metaclass(
      # the metaclass name ...
      metaclass => 'Moose::Meta::Class',
      
      # inherit the options from immutable 
      # parent class (Class::MOP::Class)
      inherit   => 1
      
      constructor_class => 'Moose::Method::Constructor',
      accessor_class    => 'Moose::Method::Accessor',    # ?? maybe    
      
      disallow => [qw[
          add_roles
          ...
      ]],
      
      memoize => [qw[
          roles
          ...
      ]]    
  );

When you specify C<inherit => 1> you are telling 
Class::MOP::Immutable that you want to inherit your 
parents options. This means that you get all their
and yours (perhaps some basic conflict resolution 
can be added here as well).

It might make sense to also allow a more granular 
approach such as:

  inherit => {
      disallow => 'merge',
      memoize  => 'override',
      readonly => 'ignore',
  }

which would allow you to specify in more detail how 
you would like to handle each change. This might be 
more than anyone ever needs so we can probably hold 
off for now.

Ultimately it will be the responsibility of the 
author to make sure their immutable options make sense.

The reason I say this is that you could easily get 
carried away in the number of items you choose to 
memoize or such. This would not make a lot of sense, 
it would make more sense to memoize at the "topmost"
level instead, rather than all the intermediate ones.

It's basically gonna be a trade off.

=cut

