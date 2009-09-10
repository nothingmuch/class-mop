use strict;
use warnings;

use Test::More tests => 4;

use Class::MOP;

my $meta = Class::MOP::Class->create('Foo');

$meta->make_immutable(constructor_name => 'foo');
ok($meta->has_method('foo'),
   "constructor is generated with correct name");
ok(!$meta->has_method('new'),
   "constructor is not generated with incorrect name");

$meta->make_mutable;
$meta->make_immutable;
{ local $TODO = "make_immutable doesn't save options yet";
ok($meta->has_method('foo'),
   "constructor is generated with correct name by default after roundtrip");
ok(!$meta->has_method('new'),
   "constructor is not generated with incorrect name by default after roundtrip");
}
