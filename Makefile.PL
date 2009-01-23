# The perl/C checking voodoo is mostly stolen from Graham Barr's
# Scalar-List-Utils distribution.
use strict;
use warnings;

use ExtUtils::MakeMaker;
use Config qw(%Config);
use File::Spec;

use 5.008;

# If undefined, try our best, if true, require XS, if false, never do
# XS
my $force_xs;

for (@ARGV) {
    /^--pm/ and $force_xs = 0;
    /^--xs/ and $force_xs = 1;
}

our $has_compiler = $force_xs;
unless ( defined $force_xs ) {
    $has_compiler = check_for_compiler()
        or no_cc();
}

my %prereqs = (
    'Scalar::Util'             => '1.18',
    'Sub::Name'                => '0.04',
    'Sub::Identify'            => '0.03',
    'MRO::Compat'              => '0.05',
    'Test::More'               => '0',
    'Test::Exception'          => '0',
    'File::Spec'               => '0',
    'Carp'                     => '0',
    'Devel::GlobalDestruction' => '0',
    'Task::Weaken'             => '0',
    'B'                        => '0',
);

delete @prereqs{qw(Sub::Name Devel::GlobalDestruction)}
    unless $has_compiler;

write_makefile();

sub write_makefile {
    my $ccflags = -d '.svn' || $ENV{MAINTAINER_MODE} ? '-Wall' : '';

    WriteMakefile(
        VERSION_FROM  => 'lib/Class/MOP.pm',
        NAME          => 'Class::MOP',
        PREREQ_PM     => \%prereqs,
        CONFIGURE     => \&init,
        CCFLAGS       => $ccflags,
        clean         => { FILES => 'test.c test.o t/pp*' },
        ABSTRACT_FROM => 'lib/Class/MOP.pm',
        AUTHOR        => 'Stevan Little <stevan@iinteractive.com>',
        LICENSE       => 'perl',
    );
}

sub no_cc {
    print <<'EOF';

 I cannot determine if you have a C compiler
 so I will install a perl-only implementation

 You can force installation of the XS version with

    perl Makefile.PL --xs

EOF
}

sub check_for_compiler {
    print "Testing if you have a C compiler\n";

    eval { require ExtUtils::CBuilder };
    if ($@) {
        return _check_for_compiler_manually();
    }
    else {
        return _check_for_compiler_with_cbuilder();
    }
}

sub _check_for_compiler_with_cbuilder {
    my $cb = ExtUtils::CBuilder->new( quiet => 1 );

    return $cb->have_compiler();
}

sub _check_for_compiler_manually {
    unless ( open F, '>', 'test.c' ) {
        warn
            "Cannot write test.c, skipping test compilation and installing pure Perl version.\n";
        return 0;
    }

    print F <<'EOF';
int main() { return 0; }
EOF

    close F or return 0;

    my $cc = $Config{cc};
    if ( $cc =~ /cl(\.exe)?$/ ) {

        # stupid stupid MSVC compiler hack tacken from version.pm's
        # Makefile.PL
        $cc .= ' -c';    # prevent it from calling the linker
    }

    system("$cc -o test$Config{obj_ext} test.c") and return 0;

    unlink $_ for grep {-f} 'test.c', "test$Config{obj_ext}";

    return 1;
}

# This sucks, but it's the best guess we can make. Since we just use
# it to run two sets of tests, it's not big deal if it ends up true
# for a non-maintainer.
sub is_maintainer {
    return 0 if $ENV{PERL5_CPAN_IS_RUNNING} || $ENV{PERL5_CPANPLUS_IS_RUNNING};

    return 1;
}

sub get_pp_tests {
    opendir my $dh, 't' or die "Cannot read t: $!";

    return grep { $_ !~ /^99/ } grep {/^\d.+\.t$/} readdir $dh;
}

# This is EUMM voodoo
sub init {
    my $hash = $_[1];

    unless ($has_compiler) {
        @{$hash}{ 'XS', 'C' } = ( {}, [] );
    }

    $hash;
}

package MY;

sub postamble {
    my @test_files = ::get_pp_tests();
    my $pp_tests = join q{ }, map { File::Spec->catfile('t', "pp_${_}") } @test_files;
    my @pp_test_targets = join qq{\n}, map {
        my $source = File::Spec->catfile('t', ${_});
        File::Spec->catfile('t', "pp_${_}") . q{: }
        . qq{$source t/header_pp.inc\n\t}
        . q{$(NOECHO) $(ABSPERLRUN) "-MExtUtils::Command" -e cat t/header_pp.inc }
        . $source . q{ > $@} . qq{\n}
    } @test_files;
    my $test_dep = $::has_compiler && (::is_maintainer() || $ENV{AUTOMATED_TESTING})
        ? qq{pure_all :: pp_tests\n} . join qq{\n}, @pp_test_targets
        : '';

    return <<"EOM"
pp_tests: ${pp_tests}

${test_dep}

EOM
}
