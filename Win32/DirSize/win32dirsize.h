/*
	##################################################################
	##################################################################
	##
	## Win32::DirSize
	## version 1.03
	##
	## by Adam Rich <arich@cpan.org>
	##
	## 10/29/2003
	##
	##################################################################
	##################################################################
*/

#ifndef __DIRSIZE_INC
#define __DIRSIZE_INC

#define DS_RESULT_OK			0
#define DS_ERR_INVALID_DIR		1
#define DS_ERR_OUT_OF_MEM		2
#define DS_ERR_DIR_TOO_BIG		3
#define DS_ERR_ACCESS_DENIED	4
#define DS_ERR_OTHER			5

// this is the main dir size function
int _dir_size (AV *errs, int permsdie, int otherdie, char *dirname, unsigned long *hightotalsize, unsigned long *lowtotalsize, long *filecount, long *dircount);

// automatically chooses the right unit
double _best_convert (char *unit, unsigned long hightotalsize, unsigned long lowtotalsize);

// converts to the unit you specify
double _size_convert (char unit, unsigned long hightotalsize, unsigned long lowtotalsize);

// this is a recursive function, not meant to be called directly
int _process_dir (AV *errs, int permsdie, int otherdie, char *dirname, char *subdirname, __int64 *totalsize, long *filecount, long *dircount);

#endif