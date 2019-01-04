#include "mex.h"
#include "NIDAQmx.h"
#include "daqmex.h"

// DAQmx_Val_Falling()
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    mxArray *outputMXArray;
    int32 *outputDataPtr;

    outputMXArray = mxCreateNumericMatrix(1,1,mxINT32_CLASS,mxREAL) ;
    outputDataPtr = (int32 *)mxGetData(outputMXArray) ;
    *outputDataPtr = DAQmx_Val_Falling ;
    plhs[0] = outputMXArray ;
    }
// end of function
