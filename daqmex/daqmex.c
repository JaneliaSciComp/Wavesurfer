#include "mex.h"
#include "NIDAQmx.h"
#include "float.h"
#include "daqmex.h"

#define ERROR_ID_BUFFER_SIZE 256

void handlePossibleDAQmxErrorOrWarning(int32 errorCode)  
    {
    char errorID[ERROR_ID_BUFFER_SIZE] ;
    const char *functionName;
    int32 rawErrorMessageBufferSize;  
    char *rawErrorMessage;  
    int32 errorMessageBufferSize;
    char *errorMessage;
    int32 errorCodeMagnitude;
    char errorCodeSignAsString[2] = "" ;

    // Ignore no-error condition, and also (controversially) ignore warnings
    if (errorCode<0)
        {
        functionName = mexFunctionName();
        rawErrorMessageBufferSize = DAQmxGetErrorString(errorCode,NULL,0);  
            // Probe to get the required buffer size
        rawErrorMessage = (char *)mxCalloc(rawErrorMessageBufferSize,sizeof(char));  
            // this is right, no +1 needed for string terminator
        errorMessageBufferSize = rawErrorMessageBufferSize+100 ;
        errorMessage = (char*) mxCalloc(errorMessageBufferSize,sizeof(char));
        DAQmxGetErrorString(errorCode,rawErrorMessage,rawErrorMessageBufferSize);
        // Can't have "-" in errorID, so work around this...
        if (errorCode>=0)
            {            
            errorCodeMagnitude = errorCode ;
            //errorCodeSignAsString = "";  // initialized to this
            }
        else
            {
            errorCodeMagnitude = -errorCode ;
            errorCodeSignAsString[0] = 'n';
            errorCodeSignAsString[1] = (char)0;
            }        
        sprintf_s(errorID, 
                  ERROR_ID_BUFFER_SIZE, 
                  "daqmex:DAQmxError:%s%d",
                  errorCodeSignAsString,
                  errorCodeMagnitude); 
        sprintf_s(errorMessage, 
                  errorMessageBufferSize, 
                  "DAQmx Error (%d) in %s: %s", 
                  errorCode, 
                  functionName, 
                  rawErrorMessage);
        //mexPrintf("here!\n");
        //mexPrintf("id: %s, msg: %s\n",errorID,errorMessage);
        mexErrMsgIdAndTxt(errorID,errorMessage);
        }
    }
// end of function


char *readStringArgument(int nrhs, const mxArray *prhs[], 
                         int index, const char *argumentName, 
                         unsigned int isEmptyAllowed, unsigned int isMissingAllowed)
    {
    char *result ;
    mwSize nCharacters,bufferSize ;
    int rc ;

    if (nrhs<index+1)
        {
        // Arg is missing
        if (isMissingAllowed) 
            {
            result = NULL ;
            }
        else
            {
            mexErrMsgIdAndTxt("daqmex:BadArgument","%s cannot be missing",argumentName);
            }
        }
    else
        {
        // Arg exists
        if ( mxIsEmpty(prhs[index]) )
            {
            if (isEmptyAllowed) 
                {
                result = NULL ;
                }
            else
                {
                mexErrMsgIdAndTxt("daqmex:BadArgument","%s cannot be empty",argumentName);
                }
            }
        else
            {
            // Arg exists, is nonempty
            if ( !mxIsChar(prhs[index]) ) 
                {
                mexErrMsgIdAndTxt("daqmex:BadArgument","%s must be a string",argumentName);
                }
            else
                {
                // Arg exists, is nonempty, is a char array
                nCharacters = mxGetNumberOfElements(prhs[index]);
                if (!isEmptyAllowed && nCharacters==0) 
                    {
                    mexErrMsgIdAndTxt("daqmex:BadArgument","%s cannot be empty",argumentName);
                    }
                bufferSize = nCharacters + 1 ;
                result = (char *)mxCalloc(bufferSize,sizeof(char));  
                rc = mxGetString(prhs[index], result, (mwSize)bufferSize);
                if (rc != 0)
                    {
                    mexErrMsgIdAndTxt("daqmex:InternalError","Problem getting %s into a C string",argumentName);
                    }
                }
            }
        }

    return result ;
    }
// end of function



float64 readTimeoutArgument(int nrhs, const mxArray *prhs[], int index)
    {
    float64 timeout;

    if (nrhs>index)
        {
        if ( mxIsEmpty(prhs[index]) )  
            {
            timeout = DAQmx_Val_WaitInfinitely ;
            }
        else if ( mxIsScalar(prhs[index]) )  
            {
            timeout = (float64) mxGetScalar(prhs[index]) ;
            if (timeout==-1.0 || timeout>=0)
                {
                if ( isfinite(timeout) )
                    {
                    // do nothing, all is well
                    }
                else
                    {
                    timeout = DAQmx_Val_WaitInfinitely ;
                    }            
                }
            else 
                {
                mexErrMsgIdAndTxt("daqmex:badArgument",
                                  "timeout must be DAQmx_Val_WaitInfinitely (-1), 0, or positive");        
                }
            }
        else 
            {
            mexErrMsgIdAndTxt("daqmex:badArgument",
                              "timeout must be a missing, empty, or a scalar");        
            }
        }
    else
        {
        timeout = DAQmx_Val_WaitInfinitely ;
        }
    
    return timeout ;
    }
// end of function




