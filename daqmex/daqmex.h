#include "mex.h"
#include "NIDAQmx.h"

#ifndef DAQMEX_H
#define DAQMEX_H

#define isfinite(x) ( _finite(x) )        // MSVC-specific, change as needed

#define EMPTY_IS_ALLOWED 1
#define EMPTY_IS_NOT_ALLOWED 0
#define MISSING_IS_ALLOWED 1
#define MISSING_IS_NOT_ALLOWED 0

void handlePossibleDAQmxErrorOrWarning(int32 errorCode) ;
char *readStringArgument(int nrhs, const mxArray *prhs[], 
                         int index, const char *argumentName, 
                         unsigned int isEmptyAllowed, unsigned int isMissingAllowed) ;
float64 readTimeoutArgument(int nrhs, const mxArray *prhs[], int index);
TaskHandle readTaskHandleArgument(int nrhs, const mxArray *prhs[]);

#endif

