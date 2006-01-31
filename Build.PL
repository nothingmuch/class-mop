use Module::Build;

use 5.6.0;

use strict;
use warnings;

my $build = Module::Build->new(
    module_name => 'Class::MOP',
    license => 'perl',
    requires => {
        'perl'            => '5.6.0',
        'Scalar::Util'    => '1.17',
        'Carp'            => '0',
        'B'               => '0',
        'Sub::Name'       => '0',
    },
    optional => {
    },
    build_requires => {
        'Test::More'      => '0.47',
        'Test::Exception' => '0',        
    },
    create_makefile_pl => 'traditional',
    recursive_test_files => 1,
    add_to_cleanup => [
        'META.yml', '*.bak', '*.gz', 'Makefile.PL',
    ],
);

$build->create_build_script;
