/*
	##################################################################
	##################################################################
	##
	## Win32::DirSize
	## version 1.00
	##
	## by Adam Rich <ar3121@sbc.com>
	##
	## 3/8/2003
	##
	##################################################################
	##################################################################
*/

#define WIN32_LEAN_AND_MEAN

#include <stdlib.h>
#include <windows.h>

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "win32dirsize.h"

double _best_convert (char *unit, unsigned long hightotalsize, unsigned long lowtotalsize) {
			if (hightotalsize	>= 268435456)	*unit = 'E';
	else	if (hightotalsize	>= 262144)		*unit = 'P';
	else	if (hightotalsize	>= 256)			*unit = 'T';
	else	if (lowtotalsize	>= 1073741824)	*unit = 'G';
	else	if (lowtotalsize	>= 1048576)		*unit = 'M';
	else	if (lowtotalsize	>= 1024)		*unit = 'K';
	else										*unit = 'B';
	
	return _size_convert (*unit, hightotalsize, lowtotalsize);
}

double _size_convert (char unit, unsigned long hightotalsize, unsigned long lowtotalsize) {
	LARGE_INTEGER nSize;
	long double converted;

	nSize.HighPart	= hightotalsize;
	nSize.LowPart	= lowtotalsize;
	converted		= (long double)nSize.QuadPart;

	switch (unit) {
		case 'E':
		case 'e':
			converted /= 1024.0;
		case 'P':
		case 'p':
			converted /= 1024.0;
		case 'T':
		case 't':
			converted /= 1024.0;
		case 'G':
		case 'g':
			converted /= 1024.0;
		case 'M':
		case 'm':
			converted /= 1024.0;
		case 'K':
		case 'k':
			converted /= 1024.0;
			break;
		default :
			converted = -1.0; // means unknown unit
	}
	return (double)converted;
}

int _dir_size (AV *errs, int permsdie, int otherdie, char *dirname, unsigned long *hightotalsize, 
	unsigned long *lowtotalsize, long *filecount, long *dircount) {

	LARGE_INTEGER nSize;
	int process_result = 0;

	nSize.HighPart	= *hightotalsize;
	nSize.LowPart	= *lowtotalsize;
	
	process_result = _process_dir (errs, permsdie, otherdie, dirname, "", 
		&(nSize.QuadPart), filecount, dircount);

	*hightotalsize	= nSize.HighPart;
	*lowtotalsize	= nSize.LowPart;

	return process_result;
}

int _process_dir (AV *errs, int permsdie, int otherdie, char *dirname, char *subdirname, 
	__int64 *totalsize, long *filecount, long *dircount) {

	char *thisdir	= NULL;
	char *wildcard	= NULL;
	WIN32_FIND_DATA fileinfo;
	HANDLE hdl;

	if (strlen (dirname) < 1) {
		return DS_ERR_INVALID_DIR;
	}

	if (strlen (subdirname) > 0) {
		// If it's not empty, we combine dirname & subdirname
		thisdir = (char *)malloc (strlen (dirname) + strlen (subdirname) + 2);

		if (thisdir == NULL) {
			return DS_ERR_OUT_OF_MEM;
		}

		strcpy (thisdir, dirname);
		strcat (thisdir, "\\");
		strcat (thisdir, subdirname);
	}
	else {
		// The first time this function is called, subdirname is empty
		thisdir = (char *)malloc (strlen (dirname) + 1);

		if (thisdir == NULL) {
			return DS_ERR_OUT_OF_MEM;
		}
		
		strcpy (thisdir, dirname);
	}

	// Prepare Wildcard for searching
	wildcard = (char *)malloc (strlen (thisdir) + 3);

	if (thisdir == NULL) {
		free (thisdir);
		return DS_ERR_OUT_OF_MEM;
	}
	
	strcpy (wildcard, thisdir);
	strcat (wildcard, "\\*");

	// Make sure Wildcard doesn't go too long.
	if (strlen (wildcard) > _MAX_PATH) {
		free (thisdir);
		free (wildcard);
		return DS_ERR_DIR_TOO_BIG;
	}

	// Execute search command
	hdl = FindFirstFile (wildcard, &fileinfo);

	if (hdl == INVALID_HANDLE_VALUE) {
		DWORD nErr = GetLastError ();

		if (nErr == ERROR_NO_MORE_FILES) {
			// Normal result, no files found in this dir.
			free (thisdir);
			free (wildcard);
			return DS_RESULT_OK;
		}
		else {
			// Push Error onto Errs array
			HV *errhash = (HV *)sv_2mortal((SV *)newHV());
			hv_store(errhash, "ErrCode", 7, newSVnv(nErr), 0);
			hv_store(errhash, "Location", 8, newSVpv(thisdir,0), 0);
			av_push(errs, newRV((SV *)errhash));
			//printf("Error: %i at %s \n", nErr, thisdir);

			free (thisdir);
			free (wildcard);

			if (( nErr == ERROR_ACCESS_DENIED ) && permsdie ) return DS_ERR_ACCESS_DENIED;
			if ( nErr == ERROR_ACCESS_DENIED ) return DS_RESULT_OK;
			
			if ( otherdie ) return DS_ERR_OTHER;
			else return DS_RESULT_OK;
		} // end of if/else
	} // end of if

	while (1) {
		// Keep recursing until we're done
		if (fileinfo.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
			// We're in a directory
			if (strcmp (".", fileinfo.cFileName) != 0 &&
				strcmp ("..", fileinfo.cFileName) != 0) {
				// Ignore these two cases

				__int64	subtotalsize	= 0;
				long	subfilecount	= 0;
				long	subdircount		= 0;
				int		process_result	= 0;

				*dircount += 1;

				process_result = _process_dir (errs, permsdie, otherdie, thisdir, fileinfo.cFileName, 
					&subtotalsize, &subfilecount, &subdircount);

				*totalsize	+= subtotalsize;
				*filecount	+= subfilecount;
				*dircount	+= subdircount;

				if (process_result != DS_RESULT_OK) {
					free (thisdir);
					free (wildcard);
					FindClose (hdl);
					return process_result;
				}
			}
		}
		else {
			// We've found a file

			// Since the FindFirstFile/FindNext File command return two 32bit signed ints, 
			// we have to use the struct/union LARGE_INTEGER to convert it to an __int64

			LARGE_INTEGER nSize;
			nSize.HighPart = fileinfo.nFileSizeHigh;
			nSize.LowPart = fileinfo.nFileSizeLow;

			*totalsize	+= nSize.QuadPart;
			*filecount	+= 1;
		} //end if/else

		// Now we continue the search
		if (! FindNextFile (hdl, &fileinfo)) {
			// Error finding the next file

			DWORD nErr = GetLastError ();
			FindClose (hdl);

			if (nErr == ERROR_NO_MORE_FILES) {
				// Normal result, no files found in this dir.
				free (thisdir);
				free (wildcard);
				return DS_RESULT_OK;
			}
			else {
				// Push Error onto Errs array
				HV *errhash = (HV *)sv_2mortal((SV *)newHV());
				hv_store(errhash, "ErrCode", 7, newSVnv(nErr), 0);
				hv_store(errhash, "Location", 8, newSVpv(thisdir,0), 0);
				av_push(errs, newRV((SV *)errhash));
				//printf("Error: %i at %s \n", nErr, thisdir);

				free (thisdir);
				free (wildcard);

				// Since we've already found the first file in this dir, we shouldn't get access denied here...
				// But we'll check anyway

				if (( nErr == ERROR_ACCESS_DENIED ) && permsdie ) return DS_ERR_ACCESS_DENIED;
				if ( nErr == ERROR_ACCESS_DENIED ) return DS_RESULT_OK;
				
				if ( otherdie ) return DS_ERR_OTHER;
				else return DS_RESULT_OK;
			} // end if/else
		} // end if
	} // end while
} // end function
