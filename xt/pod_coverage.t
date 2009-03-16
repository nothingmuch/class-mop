#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;

# This is a stripped down version of all_pod_coverage_ok which lets us
# vary the trustme parameter per module.
my @modules = all_modules();
plan tests => scalar @modules;

my %trustme = (
    'Class::MOP::Attribute' => ['process_accessors'],
    'Class::MOP::Class'     => [
        # deprecated
        'alias_method',
        'compute_all_applicable_methods',

        # unfinished feature
        'add_dependent_meta_instance',
        'add_meta_instance_dependencies',
        'invalidate_meta_instance',
        'invalidate_meta_instances',
        'remove_dependent_meta_instance',
        'remove_meta_instance_depdendencies',
        'update_meta_instance_dependencies',

        # effectively internal
        'check_metaclass_compatibility',
        'clone_instance',
        'construct_class_instance',
        'construct_instance',
        'create_meta_instance',
        'reset_package_cache_flag',
        'update_package_cache_flag',
    ],
);

for my $module ( sort @modules ) {
    my $trustme = [];
    if ( $trustme{$module} ) {
        my $methods = join '|', @{ $trustme{$module} };
        $trustme = [qr/$methods/];
    }

    pod_coverage_ok(
        $module, { trustme => $trustme },
        "Pod coverage for $module"
    );
}
