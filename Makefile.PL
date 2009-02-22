use strict;
use warnings;
use inc::Module::Install;
use 5.008001;

check_conflicts();

name 'Class-MOP';
perl_version '5.008001';
all_from 'lib/Class/MOP.pm';
license 'perl';


my $ccflags = -d '.svn' || -d '.git' || $ENV{MAINTAINER_MODE} ? '-Wall' : '';

requires 'Carp';
requires 'Devel::GlobalDestruction';
requires 'MRO::Compat' => '0.05';
requires 'Scalar::Util'     => '1.18';
requires 'Sub::Identify'    => '0.03';
requires 'Sub::Name' => '0.04';
requires 'Task::Weaken';

test_requires 'File::Spec';
test_requires 'Test::More'      => '0.77';
test_requires 'Test::Exception' => '0.21';

makemaker_args( CCFLAGS => $ccflags );

WriteAll();

# Use the cpan-smolder-stable script in the Moose svn root to figure
# out what on CPAN will break with the latest Moose, then update this
# before a release.
sub check_conflicts {
    my %conflicts = (
        'Moose' => '0.71',
    );

    my $found = 0;
    for my $mod ( sort keys %conflicts ) {
        eval "require $mod";
        next if $@;

        my $installed = $mod->VERSION();
        if ( $installed le $conflicts{$mod} ) {

            print <<"EOF";

***
    This version of Class::MOP conflicts with the version of
    $mod ($installed) you have installed.

    You will need to upgrade $mod after installing
    this version of Class::MOP.
***

EOF

            $found = 1;
        }
    }

    return unless $found;

    # More or less copied from Module::Build
    return if  $ENV{PERL_MM_USE_DEFAULT};
    return unless -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT));

    sleep 4;
}
