#!perl
# with "Class-MOP/topic/unified-method-generation-w-xs" and" Moose/topic/xs-accessor"
use strict;
use Benchmark qw(:all);
use Config; printf "Perl/%vd in $Config{archname}\n\n", $^V;
use warnings;
no warnings 'once';

my $mouse_is_loaded = eval { require Mouse };

{
	package My::Meta::Instance;
	use parent qw(Moose::Meta::Instance);
	sub can_xs{ 0 }
}

print "Class definition\n";
my $i = 0;
my $j = 0;
my $k = 0;

cmpthese 40 => {
	'Moose/Plain' => sub{
		$i++;
		my $src = '';
		for my $c(qw(A B C D E F G H I J)){
			$src .= qq{{
				package MI_$c$i;
				use Moose;
				my \$meta = __PACKAGE__->meta;
				\$meta->{instance_metaclass} = 'My::Meta::Instance';

				has attr1 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr2 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr3 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr4 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr5 => (is => 'rw', isa => 'Int', lazy_build => 1);

				\$meta->make_immutable();
			}};
		}
		eval $src or die $@;
	},
	'Moose/XS' => sub{
		$j++;
		my $src = '';
		for my $c(qw(A B C D E F G H I J)){
			$src .= qq{{
				package MX_$c$j;
				use Moose;
				my \$meta = __PACKAGE__->meta;
				#\$meta->{instance_metaclass} = 'My::Meta::Instance';

				has attr1 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr2 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr3 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr4 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr5 => (is => 'rw', isa => 'Int', lazy_build => 1);

				\$meta->make_immutable();
			}};
		}
		eval $src or die $@;
	},
	$mouse_is_loaded ? (
	'Mouse' => sub{
		$k++;
		my $src = '';
		for my $c(qw(A B C D E F G H I J)){
			$src .= qq{{
				package MU_$c$k;
				use Mouse;
				my \$meta = __PACKAGE__->meta;
				\$meta->{instance_metaclass} = 'My::Meta::Instance';

				has attr1 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr2 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr3 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr4 => (is => 'rw', isa => 'Int', lazy_build => 1);
				has attr5 => (is => 'rw', isa => 'Int', lazy_build => 1);

				\$meta->make_immutable();
			}};
		}
		eval $src or die $@;
	}) : (),
};
