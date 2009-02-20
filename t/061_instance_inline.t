use strict;
use warnings;

use Test::More tests => 6;
use Test::Exception;

use Class::MOP::Instance;

my $C = 'Class::MOP::Instance';

{
    my $instance  = '$self';
    my $slot_name = 'foo';
    my $value     = '$value';

    is($C->inline_get_slot_value($instance, $slot_name),
      '$self->{"foo"}',
      '... got the right code for get_slot_value');

    is($C->inline_set_slot_value($instance, $slot_name, $value),
      '$self->{"foo"} = $value',
      '... got the right code for set_slot_value');

    is($C->inline_initialize_slot($instance, $slot_name),
      '',
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


