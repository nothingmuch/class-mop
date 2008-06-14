use strict;
use warnings;
use inc::Module::Install;

name 'Class-MOP';
all_from 'lib/Class/MOP.pm';
license 'perl';

requires 'Scalar::Util'  => '1.18';
requires 'Sub::Name'     => '0.02';
requires 'Sub::Identify' => '0.03';
requires 'MRO::Compat'   => '0.05';
requires 'Carp'          => '0';

build_requires 'Test::More'      => '0.62';
build_requires 'Test::Exception' => '0.21';
build_requires 'File::Spec'      => '0';

auto_provides;
WriteAll();
