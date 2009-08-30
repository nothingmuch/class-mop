#!perl
# with "Class-MOP/topic/unified-method-generation-w-xs" and" Moose/topic/xs-accessor"
use strict;
use Benchmark qw(:all);
use Config; printf "Perl/%vd in $Config{archname}\n\n", $^V;
use warnings;
no warnings 'once';

my $cxsa_is_loaded = eval q{
    package CXSA;
    use Class::XSAccessor
        constructor => 'new',
        accessors   => {
            simple => 'simple',
        },
    ;
    1;
};
my $mouse_is_loaded = eval q{
	package MousePlain;
	use Mouse;
	has simple => (
		is => 'rw',
	);
	__PACKAGE__->meta->make_immutable;
};
{
	package My::Meta::Instance;
	use parent qw(Moose::Meta::Instance);
	sub can_xs{ 0 }

	package MoosePlain;
	use Moose;
	__PACKAGE__->meta->{instance_metaclass} = 'My::Meta::Instance';
	has simple => (
		is => 'rw',
	);
	has with_lazy => (
	    is      => 'rw',
	    lazy    => 1,
	    default => 42,
	);
	has with_tc => (
	    is  => 'rw',
	    isa => 'Num',
	);
	__PACKAGE__->meta->make_immutable;
}
{
	package MooseXS;
	use Moose;
	has simple => (
		is => 'rw',
	);
	has with_lazy => (
	    is      => 'rw',
	    lazy    => 1,
	    default => 42,
	);
	has with_tc => (
	    is  => 'rw',
	    isa => 'Num',
	);
	__PACKAGE__->meta->make_immutable;
}

use B qw(svref_2object);

print "Moose/$Moose::VERSION (Class::MOP/$Class::MOP::VERSION)\n";
print "Mouse/$Mouse::VERSION\n" if $mouse_is_loaded;
print "Class::XSAccessor/$Class::XSAccessor::VERSION\n" if $cxsa_is_loaded;

sub method_type{
	my($class) = @_;
	return svref_2object($class->can('simple'))->XSUB    ? 'XS'
	     : $class->meta->get_method('simple')->is_inline ? 'Inline'
	                                                     : 'Basic';
}

print 'MoosePlain: ', method_type('MoosePlain'), "\n";
print 'MooseXS:    ', method_type('MooseXS'),    "\n";

my $mi = MoosePlain->new();
my $mx = MooseXS->new();
my $mu;
$mu = MousePlain->new if $mouse_is_loaded;
my $cx;
$cx = CXSA->new       if $cxsa_is_loaded;


print "\nGETTING for simple attributes\n";
cmpthese -1 => {
	'Moose/Plain' => sub{
		my $x;
		$x = $mi->simple();
		$x = $mi->simple();
	},
	'Moose/XS' => sub{
		my $x;
		$x = $mx->simple();
		$x = $mx->simple();
	},
	$mouse_is_loaded ? (
	'Mouse' => sub{
		my $x;
		$x = $mu->simple();
		$x = $mu->simple();
	},
	) : (),
	$cxsa_is_loaded ? (
	'C::XSAccessor' => sub{
		my $x;
		$x = $cx->simple();
		$x = $cx->simple();
	},
	) : (),
};

print "\nSETTING for simple attributes\n";
cmpthese -1 => {
	'Moose/Plain' => sub{
		$mi->simple(10);
		$mi->simple(10);
	},
	'Moose/XS' => sub{
		$mx->simple(10);
		$mx->simple(10);
	},

	$mouse_is_loaded ? (
	'Mouse' => sub{
		$mu->simple(10);
		$mu->simple(10);
	},
	) : (),
	$cxsa_is_loaded ? (
	'C::XSAccessor' => sub{
		$cx->simple(10);
		$cx->simple(10);
	},
	) : (),

};

print "\nGETTING for lazy attributes (except for C::XSAccessor)\n";
cmpthese -1 => {
	'Moose/Plain' => sub{
		my $x;
		$x = $mi->with_lazy();
		$x = $mi->with_lazy();
	},
	'Moose/XS' => sub{
		my $x;
		$x = $mx->with_lazy();
		$x = $mx->with_lazy();
	},
	$cxsa_is_loaded ? (
	'C::XSAccessor' => sub{
		my $x;
		$x = $cx->simple();
		$x = $cx->simple();
	},
	) : (),
};

print "\nSETTING for attributes with type constraints (except for C::XSAccessor)\n";
cmpthese -1 => {
	'Moose/Plain' => sub{
		$mi->with_tc(10);
		$mi->with_tc(10);
	},
	'Moose/XS' => sub{
		$mx->with_tc(10);
		$mx->with_tc(10);
	},
	$cxsa_is_loaded ? (
	'C::XSAccessor' => sub{
		$cx->simple(10);
		$cx->simple(10);
	},
	) : (),
};

