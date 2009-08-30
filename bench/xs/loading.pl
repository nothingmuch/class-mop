#!perl -w
use strict;
use warnings;

use Benchmark qw(:all);
use Config; printf "Perl/%vd on $Config{archname}\n\n", $^V;

my $n      = shift || 20;

for my $module (qw(Moose KiokuDB HTTP::Engine Catalyst)){
    print "For $module\n";
    my $plain = <<"END";
    sub Moose::Meta::Instance::can_xs{ 0 }
    require Moose; # prefer Moose
    require $module;
END

    my $xs = <<"END";
    sub Moose::Meta::Instance::foo{ 0 } # dummy
    require Moose; # prefer Moose
    require $module;
END

    system(qq{$^X -e '$plain'}) == 0 or die $?;
    system(qq{$^X -e '$xs'})    == 0 or die $?;

    cmpthese  $n => {
        'Moose/Plain' => sub{
            system(qq{$^X -we '$plain'}) == 0 or die $!;
        },
        'Moose/XS' =>sub{
            system(qq{$^X -we '$xs'}) == 0 or die $!;
        },
    };
}
