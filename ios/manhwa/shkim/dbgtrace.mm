#ifdef DEBUG

#include <stdio.h>
#include <stdarg.h>

void _TRACE(const char* pszFormat, ...)
{
	char szBuffer[1024];

	va_list ap;
	va_start(ap, pszFormat);
	vsprintf(szBuffer, pszFormat, ap);
	va_end(ap);

	NSLog(@"%s", szBuffer);
}

#endif
