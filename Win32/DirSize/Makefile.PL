use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'				=> 'Win32::DirSize',
    'VERSION_FROM'		=> 'DirSize.pm',
    'PREREQ_PM'			=> {},
    ($] >= 5.005 ? (
	ABSTRACT_FROM		=> 'DirSize.pm',
	AUTHOR				=> 'Adam Rich <ar3121@sbc.com>',
	) : ()),
    'LIBS'				=> ['Kernel32.lib'],
    'DEFINE'			=> '',
    'INC'				=> '',
    'OBJECT'		=> '$(O_FILES)',
);
