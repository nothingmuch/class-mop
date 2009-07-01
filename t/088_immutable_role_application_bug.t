use strict;
use warnings;

use Test::More tests => 1;

BEGIN {

    package My::Meta::Trait;
    use Moose::Role;

    our $HAS_METH = 0;

    before 'make_immutable' => sub {
        my ($meta) = @_;

        # $meta->name->meta should have the correct methods on it..
        $HAS_METH++ if $meta->name->meta->get_method('some_method');
    };
}

{

    package TestClass;
    use Moose -traits => 'My::Meta::Trait';

    sub some_method { }

    __PACKAGE__->meta->make_immutable;
}

TODO: {
    local $TODO = 'This broke as of 07302fb';
    ok( $My::Meta::Trait::HAS_METH, 'Can find method' );
}

