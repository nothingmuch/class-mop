#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use Test::Exception;

BEGIN {
    use_ok('Class::MOP');
}

{
    package Meta::Baz;
    use strict;
    use warnings;
    use base 'Class::MOP::Class';
}

{
    package Bar;
    
    use strict;
    use warnings;
    use metaclass;           
    
    __PACKAGE__->meta->make_immutable;
    
    package Baz;
    
    use strict;
    use warnings;
    use metaclass 'Meta::Baz';    

    ::lives_ok {
        Baz->meta->superclasses('Bar');    
    } '... we survive the metaclass incompatability test';
}



