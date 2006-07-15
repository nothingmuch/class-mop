
package Class::MOP::Method;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'reftype', 'blessed';
use B            'svref_2object';

our $VERSION = '0.03';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

# construction

sub wrap { 
    my $class = shift;
    my $code  = shift;
    ('CODE' eq (reftype($code) || ''))
        || confess "You must supply a CODE reference to bless, not (" . ($code || 'undef') . ")";
    bless $code => blessed($class) || $class;
}

# informational

sub package_name { 
	my $code = shift;
	(blessed($code))
		|| confess "Can only ask the package name of a blessed CODE";
	svref_2object($code)->GV->STASH->NAME;
}

sub name { 
	my $code = shift;
	(blessed($code))
		|| confess "Can only ask the package name of a blessed CODE";	
	svref_2object($code)->GV->NAME;
}

sub fully_qualified_name {
	my $code = shift;
	(blessed($code))
		|| confess "Can only ask the package name of a blessed CODE";
	$code->package_name . '::' . $code->name;		
}

package Class::MOP::Method::Wrapped;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'reftype', 'blessed';
use Sub::Name    'subname';

our $VERSION = '0.01';

our @ISA = ('Class::MOP::Method');	

# NOTE:
# this ugly beast is the result of trying 
# to micro optimize this as much as possible
# while not completely loosing maintainability.
# At this point it's "fast enough", after all
# you can't get something for nothing :)
my $_build_wrapped_method = sub {
	my $modifier_table = shift;
	my ($before, $after, $around) = (
		$modifier_table->{before},
		$modifier_table->{after},		
		$modifier_table->{around},		
	);
	if (@$before && @$after) {
		$modifier_table->{cache} = sub {
			$_->(@_) for @{$before};
			my @rval;
			((defined wantarray) ?
				((wantarray) ? 
					(@rval = $around->{cache}->(@_)) 
					: 
					($rval[0] = $around->{cache}->(@_)))
				:
				$around->{cache}->(@_));
			$_->(@_) for @{$after};			
			return unless defined wantarray;
			return wantarray ? @rval : $rval[0];
		}		
	}
	elsif (@$before && !@$after) {
		$modifier_table->{cache} = sub {
			$_->(@_) for @{$before};
			return $around->{cache}->(@_);
		}		
	}
	elsif (@$after && !@$before) {
		$modifier_table->{cache} = sub {
			my @rval;
			((defined wantarray) ?
				((wantarray) ? 
					(@rval = $around->{cache}->(@_)) 
					: 
					($rval[0] = $around->{cache}->(@_)))
				:
				$around->{cache}->(@_));
			$_->(@_) for @{$after};			
			return unless defined wantarray;
			return wantarray ? @rval : $rval[0];
		}		
	}
	else {
		$modifier_table->{cache} = $around->{cache};
	}
};

my %MODIFIERS;

sub wrap {
	my $class = shift;
	my $code  = shift;
	(blessed($code) && $code->isa('Class::MOP::Method'))
		|| confess "Can only wrap blessed CODE";
	my $modifier_table = { 
		cache  => undef,
		orig   => $code,
		before => [],
		after  => [],		
		around => {
			cache   => $code,
			methods => [],		
		},
	};
	$_build_wrapped_method->($modifier_table);
	my $method = $class->SUPER::wrap(sub { $modifier_table->{cache}->(@_) });	
	$MODIFIERS{$method} = $modifier_table;
	$method;  
}

sub get_original_method {
	my $code = shift; 
    $MODIFIERS{$code}->{orig} 
        if exists $MODIFIERS{$code};
}

sub add_before_modifier {
	my $code     = shift;
	my $modifier = shift;
	(exists $MODIFIERS{$code})
		|| confess "You must first wrap your method before adding a modifier";		
	(blessed($code))
		|| confess "Can only ask the package name of a blessed CODE";
	('CODE' eq (reftype($code) || ''))
        || confess "You must supply a CODE reference for a modifier";			
	unshift @{$MODIFIERS{$code}->{before}} => $modifier;
	$_build_wrapped_method->($MODIFIERS{$code});
}

sub add_after_modifier {
	my $code     = shift;
	my $modifier = shift;
	(exists $MODIFIERS{$code})
		|| confess "You must first wrap your method before adding a modifier";		
	(blessed($code))
		|| confess "Can only ask the package name of a blessed CODE";
    ('CODE' eq (reftype($code) || ''))
        || confess "You must supply a CODE reference for a modifier";			
	push @{$MODIFIERS{$code}->{after}} => $modifier;
	$_build_wrapped_method->($MODIFIERS{$code});	
}

{
	# NOTE:
	# this is another possible canidate for 
	# optimization as well. There is an overhead
	# associated with the currying that, if 
	# eliminated might make around modifiers
	# more manageable.
	my $compile_around_method = sub {{
    	my $f1 = pop;
    	return $f1 unless @_;
    	my $f2 = pop;
    	push @_, sub { $f2->( $f1, @_ ) };
		redo;
	}};

	sub add_around_modifier {
		my $code     = shift;
		my $modifier = shift;
		(exists $MODIFIERS{$code})
			|| confess "You must first wrap your method before adding a modifier";		
		(blessed($code))
			|| confess "Can only ask the package name of a blessed CODE";
	    ('CODE' eq (reftype($code) || ''))
	        || confess "You must supply a CODE reference for a modifier";			
		unshift @{$MODIFIERS{$code}->{around}->{methods}} => $modifier;		
		$MODIFIERS{$code}->{around}->{cache} = $compile_around_method->(
			@{$MODIFIERS{$code}->{around}->{methods}},
			$MODIFIERS{$code}->{orig}
		);
		$_build_wrapped_method->($MODIFIERS{$code});		
	}	
}

1;

__END__

=pod

=head1 NAME 

Class::MOP::Method - Method Meta Object

=head1 SYNOPSIS

  # ... more to come later maybe

=head1 DESCRIPTION

The Method Protocol is very small, since methods in Perl 5 are just 
subroutines within the particular package. Basically all we do is to 
bless the subroutine. 

Currently this package is largely unused. Future plans are to provide 
some very simple introspection methods for the methods themselves. 
Suggestions for this are welcome. 

=head1 METHODS

=head2 Introspection

=over 4

=item B<meta>

This will return a B<Class::MOP::Class> instance which is related 
to this class.

=back

=head2 Construction

=over 4

=item B<wrap (&code)>

This simply blesses the C<&code> reference passed to it.

=back

=head2 Informational

=over 4

=item B<name>

=item B<package_name>

=item B<fully_qualified_name>

=back

=head1 Class::MOP::Method::Wrapped METHODS

=head2 Construction

=over 4

=item B<wrap (&code)>

This simply blesses the C<&code> reference passed to it.

=item B<get_original_method>

=back

=head2 Modifiers

=over 4

=item B<add_before_modifier ($code)>

=item B<add_after_modifier ($code)>

=item B<add_around_modifier ($code)>

=back

=head1 AUTHORS

Stevan Little E<lt>stevan@iinteractive.comE<gt>

Yuval Kogman E<lt>nothingmuch@woobling.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

