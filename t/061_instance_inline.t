#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP::Instance');
}

my $C = 'Class::MOP::Instance';

{
    my $instance  = '$self';
    my $slot_name = '"foo"';
    my $value     = '$value';

    is($C->inline_get_slot_value($instance, $slot_name),
      '$self->{"foo"}',
      '... got the right code for get_slot_value');

    is($C->inline_set_slot_value($instance, $slot_name, $value),
      '$self->{"foo"} = $value',
      '... got the right code for set_slot_value');

    is($C->inline_initialize_slot($instance, $slot_name),
      '$self->{"foo"} = undef',
      '... got the right code for initialize_slot');

    is($C->inline_is_slot_initialized($instance, $slot_name),
      'exists $self->{"foo"}',
      '... got the right code for get_slot_value');

    is($C->inline_weaken_slot_value($instance, $slot_name),
      'Scalar::Util::weaken( $self->{"foo"} )',
      '... got the right code for weaken_slot_value');

    is($C->inline_strengthen_slot_value($instance, $slot_name),
      '$self->{"foo"} = $self->{"foo"}',
      '... got the right code for strengthen_slot_value');
}

{
    my $instance  = '$_[0]';
    my $slot_name = '$attr_name';
    my $value     = '[]';

    is($C->inline_get_slot_value($instance, $slot_name),
      '$_[0]->{$attr_name}',
      '... got the right code for get_slot_value');

    is($C->inline_set_slot_value($instance, $slot_name, $value),
      '$_[0]->{$attr_name} = []',
      '... got the right code for set_slot_value');

    is($C->inline_initialize_slot($instance, $slot_name),
      '$_[0]->{$attr_name} = undef',
      '... got the right code for initialize_slot');

    is($C->inline_is_slot_initialized($instance, $slot_name),
      'exists $_[0]->{$attr_name}',
      '... got the right code for get_slot_value');

    is($C->inline_weaken_slot_value($instance, $slot_name),
      'Scalar::Util::weaken( $_[0]->{$attr_name} )',
      '... got the right code for weaken_slot_value');

    is($C->inline_strengthen_slot_value($instance, $slot_name),
      '$_[0]->{$attr_name} = $_[0]->{$attr_name}',
      '... got the right code for strengthen_slot_value');
}

my $accessor_string = "sub {\n"
. $C->inline_set_slot_value('$_[0]', '$attr_name', '$_[1]')
. " if scalar \@_ == 2;\n"
. $C->inline_get_slot_value('$_[0]', '$attr_name')
. ";\n}";

is($accessor_string,
   q|sub {
$_[0]->{$attr_name} = $_[1] if scalar @_ == 2;
$_[0]->{$attr_name};
}|,
    '... got the right code string for accessor');

my $reader_string = "sub {\n"
. $C->inline_get_slot_value('$_[0]', '$attr_name')
. ";\n}";

is($reader_string,
   q|sub {
$_[0]->{$attr_name};
}|,
    '... got the right code string for reader');

my $writer_string = "sub {\n"
. $C->inline_set_slot_value('$_[0]', '$attr_name', '$_[1]')
. ";\n}";

is($writer_string,
   q|sub {
$_[0]->{$attr_name} = $_[1];
}|,
    '... got the right code string for writer');


