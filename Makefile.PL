use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Class::MOP',
    VERSION_FROM => 'lib/Class/MOP.pm', 
    PREREQ_PM    => {
        'Test::More'      => '0.47',
        'Test::Exception' => '0.21',    
        'Scalar::Util'    => '1.17',
        'Sub::Name'       => '0.02',
        'Carp'            => '0.01',
        'B'               => '0',
    }
);
