use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Win32::DirSize',
    'VERSION_FROM' => 'DirSize.pm',
    'PREREQ_PM'    => { Win32::API => 0, },
    (
        $] >= 5.005
        ? (
            ABSTRACT_FROM => 'DirSize.pm',
            AUTHOR        => 'Adam Rich <ar3121@sbc.com>'
          )
        : ()
    ),
);