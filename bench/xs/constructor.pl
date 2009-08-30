#!perl -w
use strict;
use Config; printf "Perl/%vd in $Config{archname}\n\n", $^V;
use Benchmark qw(:all);

{
	package MOP_Plain;
	use metaclass;

    __PACKAGE__->meta->add_attribute('foo' => (
        reader  => 'foo',
        default => 'FOO',
    ));
    __PACKAGE__->meta->add_attribute('bar' => (
        reader  => 'bar',
        default => 'BAR',
    ));
    __PACKAGE__->meta->add_attribute('baz' => (
        reader  => 'baz',
        default => 'BAZ',
    ));
    __PACKAGE__->meta->add_attribute('bax' => (
        reader  => 'bax',
        default => 'BAX',
    ));

	no warnings 'redefine';
	local *Class::MOP::Instance::can_xs = sub{ 0 };
	__PACKAGE__->meta->make_immutable;
}
{
	package MOP_XS;
	use metaclass;

    __PACKAGE__->meta->add_attribute('foo' => (
        reader  => 'foo',
        default => 'FOO',
    ));
    __PACKAGE__->meta->add_attribute('bar' => (
        reader  => 'bar',
        default => 'BAR',
    ));
    __PACKAGE__->meta->add_attribute('baz' => (
        reader  => 'baz',
        default => 'BAZ',
    ));
    __PACKAGE__->meta->add_attribute('bax' => (
        reader  => 'bax',
        default => 'BAX',
    ));

	__PACKAGE__->meta->make_immutable;
}

# prepre caches
MOP_Plain->new;
MOP_XS->new;

print "MOP constructor (default)\n";
cmpthese -1 => {
	'Plain' => sub{
		my $x = MOP_Plain->new();
	},
	'XS'    => sub{
		my $x = MOP_XS->new();
	},
};

print "MOP constructor (non-default)\n";
cmpthese -1 => {
	'Plain' => sub{
		my $x = MOP_Plain->new(foo => 'FOO', bar => 'BAR', baz => 'BAZ');
	},
	'XS'    => sub{
		my $x = MOP_XS->new(foo => 'FOO', bar => 'BAR', baz => 'BAZ');
	},
};
