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

my $has_compiler = $force_xs;
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
        clean         => { FILES => 'test.c test.o' },
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

# This is EUMM voodoo
sub init {
    my $hash = $_[1];

    unless ($has_compiler) {
        @{$hash}{ 'XS', 'C' } = ( {}, [] );
    }

    $hash;
}
