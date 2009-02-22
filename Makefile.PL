# The perl/C checking voodoo is mostly stolen from Graham Barr's
# Scalar-List-Utils distribution.
use strict;
use warnings;

use ExtUtils::MakeMaker;
use Config qw(%Config);
use File::Spec;

use 5.008;

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

my $ccflags = -d '.svn' || -d '.git' || $ENV{MAINTAINER_MODE} ? '-Wall' : '';

WriteMakefile(
    VERSION_FROM  => 'lib/Class/MOP.pm',
    NAME          => 'Class::MOP',
    PREREQ_PM     => \%prereqs,
    CCFLAGS       => $ccflags,
    ABSTRACT_FROM => 'lib/Class/MOP.pm',
    AUTHOR        => 'Stevan Little <stevan@iinteractive.com>',
    LICENSE       => 'perl',
);
