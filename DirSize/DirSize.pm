package Win32::DirSize;

use 5.006;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);
use Win32::API;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( );
our @EXPORT_OK = qw( DirSize ToMB ToGB ToTB ToEB ToBest );
our @EXPORT = qw( DirSize );
our $VERSION = '0.01';

use constant FILE_ATTRIBUTE_READONLY			=> 0x00000001;
use constant FILE_ATTRIBUTE_HIDDEN				=> 0x00000002;
use constant FILE_ATTRIBUTE_SYSTEM				=> 0x00000004;
use constant FILE_ATTRIBUTE_DIRECTORY			=> 0x00000010;
use constant FILE_ATTRIBUTE_ARCHIVE				=> 0x00000020;
use constant FILE_ATTRIBUTE_DEVICE				=> 0x00000040;
use constant FILE_ATTRIBUTE_NORMAL				=> 0x00000080;
use constant FILE_ATTRIBUTE_TEMPORARY			=> 0x00000100;
use constant FILE_ATTRIBUTE_SPARSE_FILE			=> 0x00000200;
use constant FILE_ATTRIBUTE_REPARSE_POINT		=> 0x00000400;
use constant FILE_ATTRIBUTE_COMPRESSED			=> 0x00000800;
use constant FILE_ATTRIBUTE_OFFLINE				=> 0x00001000;
use constant FILE_ATTRIBUTE_NOT_CONTENT_INDEXED	=> 0x00002000;
use constant FILE_ATTRIBUTE_ENCRYPTED			=> 0x00004000;

use constant ERROR_NO_MORE_FILES				=> 0x00000012;
use constant INVALID_HANDLE_VALUE				=> -1;

# Import functions from shared libs
my $FindFirstFile = new Win32::API(
	'Kernel32', 
	'FindFirstFile',
	'PP',
	'N',
);
my $FindNextFile = new Win32::API(
	'Kernel32',
	'FindNextFile',
	'NP',
	'I'
);
my $FindClose = new Win32::API(
	'Kernel32', 
	'FindClose',
	'N',
	'I'
);
unless ($FindFirstFile && $FindNextFile && $FindClose) {
	die ("Fatal error: Could not import API functions");
}

sub _AllocMemory {
    my( $Length ) = @_;
    return( "\x00" x $Length );
}

sub _process_dir {
	my $DirName		= shift;
	my $SubDirName	= shift;
	my $InfoHash	= shift;

	$DirName =~ s/^\s+|\s+$//g;
	$DirName =~ s/\\+$//;

	if (defined $SubDirName) {
		$DirName .= "\\" . $SubDirName;
	}
	my $WildCard = $DirName . "\\*";

	my $FindData	= _AllocMemory(320);
	my $FindHandle	= $FindFirstFile->Call($WildCard, $FindData);

	if ($FindHandle == INVALID_HANDLE_VALUE) {
		my $LastError	= Win32::GetLastError();
		my $LastErrorT	= Win32::FormatMessage($LastError);
		$LastErrorT =~ s/\r|\n//g;

		if ($LastError != ERROR_NO_MORE_FILES) {
			$InfoHash->{IsError} = 1;
			push(@{$InfoHash->{Errors}}, {
				ErrCode	=> $LastError,
				ErrText	=> $LastErrorT,
				DirName	=> $DirName,
			});
		}
		return;
	}

	while (1) {
		my ($dwFileAttributes, $ftCreationTimeHigh, $ftCreationTimeLow,
			$ftLastAccessTimeHigh, $ftLastAccessTimeLow, $ftLastWriteTimeHigh, 
			$ftLastWriteTimeLow, $nFileSizeHigh, $nFileSizeLow, $dwReserved0, 
			$dwReserved1, $cFileName, $cAlternateFileName ) = unpack(
			'lllllllllllZ*Z*',
			$FindData,
		);

		if ($dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
			if (($cFileName ne '.') && ($cFileName ne '..')) {
				$InfoHash->{DirCount}	+= 1;

				my $MyInfoHash = {
					IsError		=>	0,
					Errors		=>	[],
					HighSize	=>	0,
					LowSize		=>	0,
					FileCount	=>	0,
					DirCount	=>	0,
				};
				_process_dir($DirName, $cFileName, $MyInfoHash);

				push(@{$InfoHash->{Errors}}, @{$MyInfoHash->{Errors}});
				$InfoHash->{IsError}	|= $MyInfoHash->{IsError};

				my $LowMax = (2**32);
				my $SpaceLeft = $LowMax - $InfoHash->{LowSize};
				if ($MyInfoHash->{LowSize} >= $SpaceLeft) {
					$InfoHash->{HighSize} += 1;
					my $OverFlow = $MyInfoHash->{LowSize} - $SpaceLeft;
					$InfoHash->{LowSize} = $OverFlow;
				}
				else {
					$InfoHash->{LowSize} += $MyInfoHash->{LowSize};
				}
				$InfoHash->{HighSize}	+= $MyInfoHash->{HighSize};
				$InfoHash->{FileCount}	+= $MyInfoHash->{FileCount};
				$InfoHash->{DirCount}	+= $MyInfoHash->{DirCount};
			}
		}
		else {
			my $LowMax = (2**32);
			my $SpaceLeft = $LowMax - $InfoHash->{LowSize};
			if ($nFileSizeLow >= $SpaceLeft) {
				$InfoHash->{HighSize} += 1;
				my $OverFlow = $nFileSizeLow - $SpaceLeft;
				$InfoHash->{LowSize} = $OverFlow;
			}
			else {
				$InfoHash->{LowSize} += $nFileSizeLow;
			}
			$InfoHash->{HighSize}	+= $nFileSizeHigh;
			$InfoHash->{FileCount}	+= 1;
		}

		my $FindNextResult = $FindNextFile->Call($FindHandle, $FindData);

		if (! $FindNextResult) {
			my $LastError	= Win32::GetLastError();
			my $LastErrorT	= Win32::FormatMessage($LastError);
			$LastErrorT =~ s/\r|\n//g;

			if ($LastError != ERROR_NO_MORE_FILES) {
				$InfoHash->{IsError} = 1;
				push(@{$InfoHash->{Errors}}, {
					ErrCode	=> $LastError,
					ErrText	=> $LastErrorT,
					DirName	=> undef,
				});
			}

			$FindClose->Call($FindHandle);
			return;
		}
	}
}

sub DirSize {
	my $DirName = shift;

	$DirName =~ s/^\s+|\s+$//g;
	$DirName =~ s/\\+$//;
	if ($DirName =~ /[a-zA-Z]:/) {
		$DirName .= '\\';
	}

	my $InfoHash = {
		IsError		=>	0,
		Errors		=>	[],
		HighSize	=>	0,
		LowSize		=>	0,
		FileCount	=>	0,
		DirCount	=>	0,
	};
	_process_dir($DirName, undef, $InfoHash);

	return $InfoHash;
}

sub ToKB {
	my $InfoHash = shift;
	my $KB;

	$KB += ($InfoHash->{HighSize} << 22);
	$KB += ($InfoHash->{LowSize} / 1024);

	return $KB;
}
sub ToMB {
	my $InfoHash = shift;
	my $MB;

	$MB += ($InfoHash->{HighSize} << 12);
	$MB += ($InfoHash->{LowSize} / 1048576);

	return $MB;
}
sub ToGB {
	my $InfoHash = shift;
	my $GB;

	$GB += ($InfoHash->{HighSize} << 2);
	$GB += ($InfoHash->{LowSize} / 1073741824);

	return $GB;
}
sub ToTB {
	my $InfoHash = shift;
	my $GB = ToGB($InfoHash);
	my $TB = $GB / 1024;

	return $TB;
}
sub ToEB {
	my $InfoHash = shift;
	my $TB = ToTB($InfoHash);
	my $EB = $TB / 1024;

	return $EB;
}
sub ToBest {
	my $InfoHash	= shift;
	my $Value		= 0;
	my $Unit		= '';
	
	if ($InfoHash->{HighSize} >= 262144) {
		$Value	= ToEB($InfoHash);
		$Unit	= 'EB';
	}
	elsif ($InfoHash->{HighSize} >= 256) {
		$Value	= ToTB($InfoHash);
		$Unit	= 'TB';
	}
	elsif ($InfoHash->{LowSize} >= 1073741824) {
		$Value	= ToGB($InfoHash);
		$Unit	= 'GB';
	}
	elsif ($InfoHash->{LowSize} >= 1048576) {
		$Value	= ToMB($InfoHash);
		$Unit	= 'MB';
	}
	elsif ($InfoHash->{LowSize} >= 1024) {
		$Value	= ToKB($InfoHash);
		$Unit	= 'KB';
	}
	else {
		$Value	= $InfoHash->{LowSize};
		$Unit	= 'B';
	}
	return {
		Value	=> $Value,
		Unit	=> $Unit,
	}
}

1;
__END__


=head1 NAME

Win32::DirSize - Calculate sizes of directories on Win32

=head1 DEPENDENCIES

Win32::API

=head1 SYNOPSIS

	### Example one:

	use Win32::DirSize qw( DirSize ToMB );

	my $Directory	= "C:\\TEMP";
	my $DirInfo		= DirSize($Directory);

	printf("Directory %s has %u files and %u subdirectories, using %0.2f MB.\n",
		$Directory,
		$DirInfo->{FileCount},
		$DirInfo->{DirCount},
		ToMB($DirInfo),
	);

	### Example two:

	use Win32::DirSize qw( DirSize ToBest );

	my $Directory	= "C:\\TEMP";
	my $DirInfo		= DirSize($Directory);
	my $SizeInfo	= ToBest($DirInfo);

	printf("Directory %s has %u files and %u subdirectories, using %0.2f %s.\n",
		$Directory,
		$DirInfo->{FileCount},
		$DirInfo->{DirCount},
		$SizeInfo->{Value},
		$SizeInfo->{Unit},
	);

	if ($DirInfo->{IsError}) {
		print "Errors encountered were:\n";
		foreach my $error (@{$DirInfo->{Errors}}) {
			printf("Error #%u: %s in directory %s\n", 
				$error->{ErrCode}, 
				$error->{ErrText},
				$error->{DirName} ? $error->{DirName} : 'N/A',
			);
		}
	}

=head1 DESCRIPTION

	Win32::DirSize will calculate the total size used by any directory on your
	Win32 file system.  It can also give you the total count of files or directories
	under that directory.

	The main function is DirSize() - takes a directory as an argument and returns a single hashref.
	The hashref keys are: IsError, Errors, HighSize, LowSize, FileCount, DirCount.

	Since the maximum size a single integer can represent is 4 GB, Win32::DirSize uses
	two integers, HighSize to represent the upper 32 bits, and LowSize to represent the lower 32 bits.
	This allows a maximum size of over 16,000 exabytes.

	If you prefer to work with the raw size in bytes, I suggest the Math::BigInt module.

	There are four helper functions to convert these values into something more usable:
	ToMB(), ToGB(), ToTB(), and ToEB() to calculate megabytes, gigabytes, terabytes, 
	and exabytes respectively.  

	Note: For sizes over 4 terabytes, avoid ToKB().  Use one of the other functions.
	Note: For sizes over 4 exabytes, avoid ToKB() and ToMB().  Use one of the other functions.
	Note: For sizes over 4096 exabytes, avoid ToKB() and ToMB() and ToGB().  Use one of the other functions.

	If you don't know the general size of the directory before hand, you can use ToBest().
	This function will determine the best unit for the size and return a hashref with the 
	reduced size and chosen unit.  

	In the process of recursing through directories, any errors will set IsError to true.
	A description of the error in the form of a hashref is pushed onto the Errors array ref.
	Usually, these errors are "Access Denied" messages for locked or secured directories.

=head1 EXPORT

DirSize is exported by default.

=head1 EXPORT OK

Optional exports are: DirSize ToMB ToGB ToTB ToEB ToBest

=head1 AUTHOR

Adam Rich (ar3121@sbc.com)

=cut
