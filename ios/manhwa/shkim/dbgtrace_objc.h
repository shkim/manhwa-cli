#ifndef __DBGTRACE_OBJC_H__
#define __DBGTRACE_OBJC_H__

#ifdef DEBUG
	#include <assert.h>

	#ifndef _DEBUG
	#define _DEBUG
	#endif

	#define ASSERT(f)	assert(f)
	#define NSTRACE		NSLog
	#define TRACE		_TRACE
	#define VERIFY		ASSERT

#ifdef __cplusplus
	extern "C" void _TRACE(const char* szFormat, ...);
#ifdef __OBJC__
	void NSTRACE(NSString* szFormat, ...);
#endif
#endif	// __cplusplus

#else
	#define	TRACE(...)
	#define NSTRACE(...)
	#define ASSERT(f)		((void)0)
	#define VERIFY(f)		((void)0)
#endif

#endif
