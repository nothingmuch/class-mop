use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Class::MOP',
    VERSION_FROM => 'lib/Class/MOP.pm', 
    PREREQ_PM    => {
        'Test::More'      => 0,
        'Test::Exception' => 0,
        'Scalar::Util'    => 0,
        'Carp'            => 0,
        'B'               => 0,
        'Sub::Name'       => 0,        
    }
);
