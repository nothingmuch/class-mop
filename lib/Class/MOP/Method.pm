
package Class::MOP::Method;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'reftype', 'blessed';
use B            'svref_2object';

our $VERSION = '0.02';

# introspection

sub meta { 
    require Class::MOP::Class;
    Class::MOP::Class->initialize(blessed($_[0]) || $_[0]);
}

# construction

sub new { 
    my $class = shift;
    my $code  = shift;
    (reftype($code) && reftype($code) eq 'CODE')
        || confess "You must supply a CODE reference to bless";
    bless $code => blessed($class) || $class;
}

{
	my %MODIFIERS;
	
	sub wrap {
		my $code = shift;
		(blessed($code))
			|| confess "Can only ask the package name of a blessed CODE";
		my $modifier_table = { 
			orig   => $code,
			before => [],
			after  => [],		
			around => {
				cache   => $code,
				methods => [],
			},
		};
		my $method = $code->new(sub {
			$_->(@_) for @{$modifier_table->{before}};
			my @rval;
			if (defined wantarray) {
				@rval = $modifier_table->{around}->{cache}->(@_);
			}
			else {
				$modifier_table->{around}->{cache}->(@_);
			}
			$_->(@_) for @{$modifier_table->{after}};			
			return unless defined wantarray;
			return wantarray ? @rval : $rval[0];
		});	
		$MODIFIERS{$method} = $modifier_table;
		$method;  
	}
	
	sub add_before_modifier {
		my $code     = shift;
		my $modifier = shift;
		(exists $MODIFIERS{$code})
			|| confess "You must first wrap your method before adding a modifier";		
		(blessed($code))
			|| confess "Can only ask the package name of a blessed CODE";
	    (reftype($modifier) && reftype($modifier) eq 'CODE')
	        || confess "You must supply a CODE reference for a modifier";			
		unshift @{$MODIFIERS{$code}->{before}} => $modifier;
	}
	
	sub add_after_modifier {
		my $code     = shift;
		my $modifier = shift;
		(exists $MODIFIERS{$code})
			|| confess "You must first wrap your method before adding a modifier";		
		(blessed($code))
			|| confess "Can only ask the package name of a blessed CODE";
	    (reftype($modifier) && reftype($modifier) eq 'CODE')
	        || confess "You must supply a CODE reference for a modifier";			
		push @{$MODIFIERS{$code}->{after}} => $modifier;
	}
	
	{
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
		    (reftype($modifier) && reftype($modifier) eq 'CODE')
		        || confess "You must supply a CODE reference for a modifier";			
			unshift @{$MODIFIERS{$code}->{around}->{methods}} => $modifier;		
			$MODIFIERS{$code}->{around}->{cache} = $compile_around_method->(
				@{$MODIFIERS{$code}->{around}->{methods}},
				$MODIFIERS{$code}->{orig}
			);
		}	
	}
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

=item B<new (&code)>

This simply blesses the C<&code> reference passed to it.

=back

=head2 Informational

=over 4

=item B<name>

=item B<package_name>

=back

=head1 SEE ALSO

http://dirtsimple.org/2005/01/clos-style-method-combination-for.html

http://www.gigamonkeys.com/book/object-reorientation-generic-functions.html

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut