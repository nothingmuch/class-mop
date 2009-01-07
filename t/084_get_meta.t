use strict;
use warnings;
use Test::More tests => 4;

require Class::MOP;

is(Class::MOP::get_meta('Does::Not::Exist'), undef, "... get_meta on a nonexistent class returns undef");
is(Class::MOP::get_meta(bless {}, 'Does::Not::Exist'), undef, "... get_meta on an instance of a nonexistent class returns undef");

is(Class::MOP::get_meta('Class::MOP::Class'), Class::MOP::Class->meta, "... get_meta on Class::MOP::Class returns its metaclass");
is(Class::MOP::get_meta(bless {}, 'Class::MOP::Class'), Class::MOP::Class->meta, "... get_meta on an instance of Class::MOP::Class returns its metaclass");

