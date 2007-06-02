#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use File::Spec::Functions;

use Test::More tests => 10;
use Test::Exception;
use Scalar::Util;

BEGIN {
    use_ok('Class::MOP');
}

use lib catdir($FindBin::Bin, 'lib');

{
    package Foo;

    use strict;
    use warnings;
    use metaclass;

    __PACKAGE__->meta->make_immutable;

    package Bar;

    use strict;
    use warnings;
    use metaclass;

    __PACKAGE__->meta->make_immutable;

    package Baz;

    use strict;
    use warnings;
    use metaclass 'MyMetaClass';

    sub mymetaclass_attributes{
      shift->meta->mymetaclass_attributes;
    }

    ::lives_ok {
        Baz->meta->superclasses('Bar');
    } '... we survive the metaclass incompatability test';
}

{
    my $meta = Baz->meta;
    is(Foo->meta->blessed, Bar->meta->blessed, 'Foo and Bar immutable metaclasses match');
    is($meta->blessed, 'MyMetaClass', 'Baz->meta blessed as MyMetaClass');
    ok(Baz->can('mymetaclass_attributes'), '... Baz can do method before immutable');
    ok($meta->can('mymetaclass_attributes'), '... meta can do method before immutable');
    $meta->make_immutable;
    isa_ok($meta, 'MyMetaClass', 'Baz->meta');
    ok(Baz->can('mymetaclass_attributes'), '... Baz can do method after imutable');
    ok($meta->can('mymetaclass_attributes'), '... meta can do method after immutable');
    isnt(Baz->meta->blessed, Bar->meta->blessed, 'Baz and Bar immutable metaclasses are different');
}
