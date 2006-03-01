
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

sub wrap { 
    my $class = shift;
    my $code  = shift;
    ('CODE' eq (reftype($code) || ''))
        || confess "You must supply a CODE reference to bless";
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

package Class::MOP::Method::Wrapped;

use strict;
use warnings;

use Carp         'confess';
use Scalar::Util 'reftype', 'blessed';

our $VERSION = '0.01';

our @ISA = ('Class::MOP::Method');	

my %MODIFIERS;

sub wrap {
	my $class = shift;
	my $code  = shift;
	(blessed($code) && $code->isa('Class::MOP::Method'))
		|| confess "Can only wrap blessed CODE";
	my $modifier_table = { 
		orig   => $code,
		before => [],
		after  => [],		
		around => {
			cache   => $code,
			methods => [],
		},
	};
	my $method = $class->SUPER::wrap(sub {
		$_->(@_) for @{$modifier_table->{before}};
		my (@rlist, $rval);
		if (defined wantarray) {
			if (wantarray) {
				@rlist = $modifier_table->{around}->{cache}->(@_);
			}
			else {
				$rval = $modifier_table->{around}->{cache}->(@_);
			}
		}
		else {
			$modifier_table->{around}->{cache}->(@_);
		}
		$_->(@_) for @{$modifier_table->{after}};			
		return unless defined wantarray;
		return wantarray ? @rlist : $rval;
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
	('CODE' eq (reftype($code) || ''))
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
    ('CODE' eq (reftype($code) || ''))
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
	    ('CODE' eq (reftype($code) || ''))
	        || confess "You must supply a CODE reference for a modifier";			
		unshift @{$MODIFIERS{$code}->{around}->{methods}} => $modifier;		
		$MODIFIERS{$code}->{around}->{cache} = $compile_around_method->(
			@{$MODIFIERS{$code}->{around}->{methods}},
			$MODIFIERS{$code}->{orig}
		);
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

=item B<wrap>

This wraps an existing method so that it can handle method modifiers.

=back

=head2 Informational

=over 4

=item B<name>

=item B<package_name>

=back

=head2 Modifiers

=over 4

=item B<add_before_modifier ($code)>

=item B<add_after_modifier ($code)>

=item B<add_around_modifier ($code)>

=back

=head1 AUTHOR

Stevan Little E<lt>stevan@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006 by Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut