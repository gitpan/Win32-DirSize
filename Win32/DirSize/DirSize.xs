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

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "win32dirsize.h"

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double
constant_DS_ERR_O(char *name, int len, int arg)
{
    switch (name[8 + 0]) {
    case 'T':
	if (strEQ(name + 8, "THER")) {	/* DS_ERR_O removed */
#ifdef DS_ERR_OTHER
	    return DS_ERR_OTHER;
#else
	    goto not_there;
#endif
	}
    case 'U':
	if (strEQ(name + 8, "UT_OF_MEM")) {	/* DS_ERR_O removed */
#ifdef DS_ERR_OUT_OF_MEM
	    return DS_ERR_OUT_OF_MEM;
#else
	    goto not_there;
#endif
	}
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}

static double
constant_DS_E(char *name, int len, int arg)
{
    if (4 + 3 >= len ) {
	errno = EINVAL;
	return 0;
    }
    switch (name[4 + 3]) {
    case 'A':
	if (strEQ(name + 4, "RR_ACCESS_DENIED")) {	/* DS_E removed */
#ifdef DS_ERR_ACCESS_DENIED
	    return DS_ERR_ACCESS_DENIED;
#else
	    goto not_there;
#endif
	}
    case 'D':
	if (strEQ(name + 4, "RR_DIR_TOO_BIG")) {	/* DS_E removed */
#ifdef DS_ERR_DIR_TOO_BIG
	    return DS_ERR_DIR_TOO_BIG;
#else
	    goto not_there;
#endif
	}
    case 'I':
	if (strEQ(name + 4, "RR_INVALID_DIR")) {	/* DS_E removed */
#ifdef DS_ERR_INVALID_DIR
	    return DS_ERR_INVALID_DIR;
#else
	    goto not_there;
#endif
	}
    case 'O':
	if (!strnEQ(name + 4,"RR_", 3))
	    break;
	return constant_DS_ERR_O(name, len, arg);
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}

static double
constant(char *name, int len, int arg)
{
    errno = 0;
    if (0 + 3 >= len ) {
	errno = EINVAL;
	return 0;
    }
    switch (name[0 + 3]) {
    case 'E':
	if (!strnEQ(name + 0,"DS_", 3))
	    break;
	return constant_DS_E(name, len, arg);
    case 'R':
	if (strEQ(name + 0, "DS_RESULT_OK")) {	/*  removed */
#ifdef DS_RESULT_OK
	    return DS_RESULT_OK;
#else
	    goto not_there;
#endif
	}
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}


MODULE = Win32::DirSize		PACKAGE = Win32::DirSize		


double
constant(sv,arg)
    PREINIT:
	STRLEN		len;
    INPUT:
	SV *		sv
	char *		s = SvPV(sv, len);
	int		arg
    CODE:
	RETVAL = constant(s,len,arg);
    OUTPUT:
	RETVAL

int 
dir_size (dirname,dirinfo,permsdie=0,otherdie=0)
	PREINIT:
		AV *errs			= newAV();
		HV *newdirinfo			= newHV();
		unsigned long hightotalsize	= 0;
		unsigned long lowtotalsize	= 0;
		long filecount			= 0;
		long dircount			= 0;
		int dirnamelen			= 0;
	INPUT:
		SV *dirinfo;
		char *dirname;
		int permsdie;
		int otherdie;
	CODE:
		dirnamelen = strlen(dirname);
		while (dirname[dirnamelen-1] == '\\') {
			dirname[dirnamelen-1] = '\0';
			dirnamelen = strlen(dirname);
		}

		RETVAL = _dir_size (errs, permsdie, otherdie, dirname, &hightotalsize, &lowtotalsize, &filecount, &dircount);
		hv_store(newdirinfo, "Errors",		6, newRV_noinc((SV *)errs), 0);
		hv_store(newdirinfo, "HighSize",	8, newSVuv(hightotalsize), 0);
		hv_store(newdirinfo, "LowSize",		7, newSVuv(lowtotalsize), 0);
		hv_store(newdirinfo, "FileCount",	9, newSViv(filecount), 0);
		hv_store(newdirinfo, "DirCount",	8, newSViv(dircount), 0);

		sv_setsv(dirinfo, sv_2mortal(newRV_noinc((SV *)newdirinfo)));
	OUTPUT:
		dirinfo
		RETVAL

double
best_convert (unit, hightotalsize, lowtotalsize)
	INPUT:
		char &unit;
		unsigned long hightotalsize;
		unsigned long lowtotalsize;
	CODE:
		RETVAL = _best_convert (&unit, hightotalsize, lowtotalsize);
	OUTPUT:
		RETVAL
		unit

double
size_convert (unit, hightotalsize, lowtotalsize)
	INPUT:
		char unit;
		unsigned long hightotalsize;
		unsigned long lowtotalsize;
	CODE:
		RETVAL = _size_convert (unit, hightotalsize, lowtotalsize);
	OUTPUT:
		RETVAL
