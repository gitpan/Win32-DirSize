
	##################################################################
	##################################################################
	##
	## Win32::DirSize
	## version 1.01
	##
	## by Adam Rich <ar3121@sbc.com>
	##
	## 3/8/2003
	##
	##################################################################
	##################################################################

package Win32::DirSize;

use 5.006;
use strict;
use warnings;
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader;

our @ISA = qw(Exporter DynaLoader);

our %EXPORT_TAGS = ();
our @EXPORT_OK = qw(
	DS_ERR_ACCESS_DENIED
	DS_ERR_DIR_TOO_BIG
	DS_ERR_INVALID_DIR
	DS_ERR_OTHER
	DS_ERR_OUT_OF_MEM
	DS_RESULT_OK
	dir_size
	best_convert
	size_convert
);
our @EXPORT = qw(
	DS_ERR_ACCESS_DENIED
	DS_ERR_DIR_TOO_BIG
	DS_ERR_INVALID_DIR
	DS_ERR_OTHER
	DS_ERR_OUT_OF_MEM
	DS_RESULT_OK
	dir_size
	best_convert
	size_convert
);
our $VERSION = '1.01';

sub AUTOLOAD {
    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "& not defined" if $constname eq 'constant';
    local $! = 0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
		if ($! =~ /Invalid/ || $!{EINVAL}) {
			$AutoLoader::AUTOLOAD = $AUTOLOAD;
			goto &AutoLoader::AUTOLOAD;
		}
		else {
			croak "Your vendor has not defined Win32::DirSize macro $constname";
		}
    }
    {
		no strict 'refs';
		*$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

bootstrap Win32::DirSize $VERSION;

1;
__END__

=head1 NAME

Win32::DirSize - Calculate sizes of directories on Win32

=head1 SYNOPSIS

 use strict;  
 use Win32::DirSize;
 
 my $Directory = "C:\\TEMP";
 my $DirInfo;
 my $Result = dir_size(
   $Directory,
   $DirInfo,
 );
 
 if ($Result == DS_RESULT_OK) {
   my $Unit;
   my $Size = best_convert(
     $Unit, 
     $DirInfo->{HighSize}, 
     $DirInfo->{LowSize},
   );
   printf(
     "%u files and %u directories found in %s, totalling %.2f%s\n",
     $DirInfo->{FileCount}, 
     $DirInfo->{DirCount}, 
     $Directory,
     $Size,
     $Unit,
   );
   if (@{$DirInfo->{Errors}}) {
     foreach my $Error (@{$DirInfo->{Errors}}) {
       printf(
         "Error #%d at %s\n",
         $Error->{ErrCode},
         $Error->{Location},
       );
     }
   }
 }

=head1 DESCRIPTION

Win32::DirSize will calculate the total size used by any directory on your
Win32 file system.  It can also give you the total count of files or directories
under that directory.  Informal benchmarks suggest this version of Win32::DirSize
to be up to 50x faster than using File::Find.

Since directory sizes on Win32 systems can easily reach the multi-terabyte range and
beyond, and the result perl can store in a single 32-bit integer is 2 GB, it's not possible
to return an accurate result in a single variable. So, the Win32 API and this module 
return the result in two seperate values representing the least and most significant 
32 bits.

You can manipulate these values yourself, use the Math::BigInt module, or take 
advantage of the size_convert() and best_convert() functions described below.


=head2 Function definitions

=over

=item dir_size(dirname, dirinfo [, permsdie [, othersdie]])

dir_size() will take the name of a directory, and a scalar variable, and attempt to determine
the size, filecount, and directory count of the directory you specified.  It puts this information
into the scalar variable you provided in the form of a hashref.  

The hashref will contain 5 keys: 

=over

=item HighSize

This is an integer value containing the most significant 32 bits of the total file size.

=item LowSize

This is an integer value containing the least significant 32 bits of the total file size.
The HighSize & LowSize values can be converted to usable numbers via the size_convert() and
best_convert() functions, or you can use the Math::BigInt module if you have it.

=item FileCount

This is an integer value containing the count of the files found beneath the directory
you specified.

=item DirCount

This is an integer value containing the count of the subdirectories found beneath the directory
you specified.

=item Errors

This is a reference to an array containing hashes, explained in more detail below.

=back

Sometimes, while recursing through a directory, dir_size() may encounter a directory or file that it
can't access.  The most common reason for this is that you lack sufficient permissions to open that
directory.  If you'd prefer dir_size() quit immediately when this happens, specify 1 for the "permsdie"
parameter.  The default is to ignore the error and continue.  Other types of errors besides "access
denied" are rare, but they can happen.  Specify 1 for the "othersdie" parameter if you'd like to
quit for other types of errors as well.  The default is to ignore them.

When it's finished, dir_size() will return an integer value indicating the status of the operation.
If no errors were encountered, the result will be DS_RESULT_OK.  If you specified a 1 for "permsdie"
and dir_size encountered a directory it had no rights to, the result will be DS_ERR_ACCESS_DENIED.
And similarily, if you specified 1 for "othersdie" and a different type of file/directory error
was encountered, the result will be DS_ERR_OTHER.  There are 3 other types of status you may see:
DS_ERR_DIR_TOO_BIG means the directory name was too long, DS_ERR_INVALID_DIR means the directory
was an invalid format, and DS_ERR_OUT_OF_MEM means that a memory allocation failed.

Regardless of what values you specified for "permsdie" and "othersdie", any file/directory errors
encountered during the operation are recorded in a list of hashes referenced in the "Errors" key of
the dirinfo hashref.  Each hash will contain two keys: 'ErrCode' for the operating system's error
code value, and 'Location' for the name of the directory where the error was encountered.

=item best_convert(unit, highsize, lowsize)

best_convert() is used to convert the directory size in bytes calculated by dir_size() into the best
a printable format automatically.  It will determine the best unit for the magnitude of your 
directory size, convert the size to that unit, and return the result to you.  The variable you 
passed in for the "unit" paramter is set to the unit chosen.  The result is returned in a
double float format.

=item size_convert(unit, highsize, lowsize)

size_convert() can be used to convert the directory size in bytes calculated by dir_size() into 
another unit.  The units to choose from include k, M, G, T, P, E for kilobytes, megabytes, gigabytes,
terabytes, petabytes, and exabytes respectively.  If you provide an invalid unit, this function 
will return -1 to indicate an error.  Keep in mind that if you have an extremely large size value 
stored in highsize/lowsize and don't choose a large enough unit for it, the returned value may get 
truncated while being converted to a double float.

=back

=head2 

=head2 EXPORT

	Functions: dir_size() best_convert() size_convert()
	Constants: DS_ERR_ACCESS_DENIED DS_ERR_DIR_TOO_BIG 
		DS_ERR_INVALID_DIR DS_ERR_OTHER DS_ERR_OUT_OF_MEM 
		DS_RESULT_OK

=head1 AUTHOR

Adam Rich (ar3121@sbc.com)

=cut
