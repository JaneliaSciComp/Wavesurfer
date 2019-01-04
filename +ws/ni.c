#include <string.h>
#include "float.h"
#include "mex.h"
#include "matrix.h"
#include "NIDAQmx.h"
//#include "daqmex.h"



#define ERROR_ID_BUFFER_SIZE 256
#define EMPTY_IS_ALLOWED 1
#define EMPTY_IS_NOT_ALLOWED 0
#define MISSING_IS_ALLOWED 1
#define MISSING_IS_NOT_ALLOWED 0



// Define the 'instance variables' for the 'Singleton'
// We use these to check TaskHandles ofr validity, and thus
// avoid segfaulting.
#define MAXIMUM_TASK_HANDLE_COUNT 32 
TaskHandle TASK_HANDLES[MAXIMUM_TASK_HANDLE_COUNT] ;
mwSize TASK_HANDLE_COUNT = 0 ;



#define isfinite(x) ( _finite(x) )        // MSVC-specific, change as needed



void handlePossibleDAQmxErrorOrWarning(int32 errorCode)  {
    char errorID[ERROR_ID_BUFFER_SIZE] ;
    const char *functionName;
    int32 rawErrorMessageBufferSize;  
    char *rawErrorMessage;  
    int32 errorMessageBufferSize;
    char *errorMessage;
    int32 errorCodeMagnitude;
    char errorCodeSignAsString[2] = "" ;

    // Ignore no-error condition, and also (controversially) ignore warnings
    if (errorCode<0)  {
        functionName = mexFunctionName();
        rawErrorMessageBufferSize = DAQmxGetErrorString(errorCode,NULL,0);  
            // Probe to get the required buffer size
        rawErrorMessage = (char *)mxCalloc(rawErrorMessageBufferSize,sizeof(char));  
            // this is right, no +1 needed for string terminator
        errorMessageBufferSize = rawErrorMessageBufferSize+100 ;
        errorMessage = (char*) mxCalloc(errorMessageBufferSize,sizeof(char));
        DAQmxGetErrorString(errorCode,rawErrorMessage,rawErrorMessageBufferSize);
        // Can't have "-" in errorID, so work around this...
        if (errorCode>=0)  {            
            errorCodeMagnitude = errorCode ;
            //errorCodeSignAsString = "";  // initialized to this
        }
        else {
            errorCodeMagnitude = -errorCode ;
            errorCodeSignAsString[0] = 'n';
            errorCodeSignAsString[1] = (char)0;
        }
        sprintf_s(errorID, 
                  ERROR_ID_BUFFER_SIZE, 
                  "ws:ni:DAQmxError:%s%d",
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



// Note that you should mxFree() the thing returned by readStringArgument when done with it
char *readStringArgument(int nrhs, const mxArray *prhs[], 
                         int index, const char *argumentName, 
                         unsigned int isEmptyAllowed, unsigned int isMissingAllowed)  {
    char *result = NULL ;

    if (nrhs<index+1)  {
        // Arg is missing
        if (isMissingAllowed)  {
            result = NULL ;
        }
        else  {
            mexErrMsgIdAndTxt("ws:ni:BadArgument","%s cannot be missing",argumentName);
        }
    }
    else  {
        // Arg exists
        if ( mxIsEmpty(prhs[index]) )  {
            if (isEmptyAllowed)  {
                result = NULL ;
            }
            else {
                mexErrMsgIdAndTxt("ws:ni:BadArgument","%s cannot be empty",argumentName);
            }
        }
        else {
            // Arg exists, is nonempty
            if ( !mxIsChar(prhs[index]) )  {
                mexErrMsgIdAndTxt("ws:ni:BadArgument","%s must be a string",argumentName);
            }
            else {
                // Arg exists, is nonempty, is a char array
                result = mxArrayToString(prhs[index]) ;  // Do I need to free this?  Yes, with mxFree()
                if (!result)  {
                    mexErrMsgIdAndTxt("ws:ni:InternalError", "Problem getting %s into a C string", argumentName);
                }
            }
        }
    }

    return result ;
}
// end of function



float64 readTimeoutArgument(int nrhs, const mxArray *prhs[], int index)  {
    float64 timeout;

    if (nrhs>index)  {
        if ( mxIsEmpty(prhs[index]) )  {
            timeout = DAQmx_Val_WaitInfinitely ;
        }
        else if ( mxIsScalar(prhs[index]) )  {
            timeout = (float64) mxGetScalar(prhs[index]) ;
            if (timeout==-1.0 || timeout>=0)  {
                if ( isfinite(timeout) )  {
                    // do nothing, all is well
                }
                else  {
                    timeout = DAQmx_Val_WaitInfinitely ;
                }
            }
            else  {
                mexErrMsgIdAndTxt("ws:ni:badArgument",
                                  "timeout must be DAQmx_Val_WaitInfinitely (-1), 0, or positive");        
            }
        }
        else  {
            mexErrMsgIdAndTxt("ws:ni:badArgument",
                              "timeout must be a missing, empty, or a scalar");        
        }
    }
    else  {
        timeout = DAQmx_Val_WaitInfinitely ;
    }
    
    return timeout ;
}
// end of function


// Utility to look up value names
bool daqmxValueFromString(const char * valueAsString, int32 * result)  {
    bool didSucceed = true ;
    // Dispatch on the method name
    if ( strcmp(valueAsString,"DAQmx_Val_ContSamps")==0 )  {
        *result = DAQmx_Val_ContSamps ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Falling")==0 )  {
        *result = DAQmx_Val_Falling ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_FiniteSamps")==0 )  {
        *result = DAQmx_Val_FiniteSamps ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Rising")==0 )  {
        *result = DAQmx_Val_Rising ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Abort")==0 )  {
        *result = DAQmx_Val_Task_Abort ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Commit")==0 )  {
        *result = DAQmx_Val_Task_Commit ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Reserve")==0 )  {
        *result = DAQmx_Val_Task_Reserve ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Start")==0 )  {
        *result = DAQmx_Val_Task_Start ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Stop")==0 )  {
        *result = DAQmx_Val_Task_Stop ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Unreserve")==0 )  {
        *result = DAQmx_Val_Task_Unreserve ;
    }
    else if ( strcmp(valueAsString,"DAQmx_Val_Task_Verify")==0 )  {
        *result = DAQmx_Val_Task_Verify ;
    }
    else  {
        // Doesn't match anything, so error
        didSucceed = false ;
    }
    return didSucceed ;
}


int32 readValueArgument(int nrhs, const mxArray *prhs[], 
                        int index, const char *argumentName)  {
    char * valueAsString ;
    int32 result ;
    
    valueAsString = 
        readStringArgument(nrhs, prhs, 
                           index, argumentName, 
                           EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED) ;  // Need to mxFree() this at some point
    bool didSucceed = daqmxValueFromString(valueAsString, &result) ;
    mxFree(valueAsString) ;
    if (!didSucceed)  {
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          "Did not recognize value %s for argument %s", valueAsString, argumentName);
    }
    
    return result ;
}

    

// Helper function for reading a task handle argument and validating it
TaskHandle readTaskHandleArgument(int nrhs, const mxArray *prhs[])  {
    TaskHandle taskHandle ;
    bool isTaskHandleValid ;
    mwSize i ;

    // Read the task handle argument, which, when present, is always the second argument (i.e. the one after the 'method' name)
    if ( (nrhs>1) && mxIsUint64(prhs[1]) && mxIsScalar(prhs[1]) )  {
        taskHandle = *((TaskHandle*) mxGetData(prhs[1])) ;
        // Check that this is a valid taskHandle.  If we didn't do this check, then handing in an invalid taskHandle
        // could cause Matlab to dump core.
        isTaskHandleValid = false ;
        for (i=0; i<TASK_HANDLE_COUNT; ++i)  {
            //mexPrintf("Checking one registered task handle against the given one.\n");
            //mexPrintf("taskHandle: %llu\n", (uInt64)(taskHandle)) ;
            //mexPrintf("TASK_HANDLES[i]: %llu\n", (uInt64)(TASK_HANDLES[i])) ;
            if ( taskHandle == TASK_HANDLES[i] )  {
                //mexPrintf("Found a match!\n");
                isTaskHandleValid = true ;
                break ;
            }
        }
        //mexPrintf("isTaskHandleValid: %d\n", isTaskHandleValid) ;
        if (!isTaskHandleValid)  {
            mexErrMsgIdAndTxt("ws:ni:badArgument",
                              "taskHandle is not a registered task handle");
        }
        // If get here, taskHandle is a registered task handle
    }
    else  {
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          "taskHandle must be a uint64 scalar");
    }

    return taskHandle ;
}
// end of function



// Utility function
bool isMxArrayAString(const mxArray* arg)  {
    // Check that stringAsMxArray is a proper Matlab string
    if ( mxGetClassID(arg)!=mxCHAR_CLASS )  {
        return false;
    }
    
    // Check that stringAsMxArray is 2D
    if ( mxGetNumberOfDimensions(arg)!=2 )  {
        return false;
    }
    
    // Check that stringAsMxArray is either 0x0 or 1xn, for natural n
    uInt64 m = (uInt64)(mxGetM(arg)) ;
    uInt64 n = (uInt64)(mxGetN(arg)) ;
    bool isRowVector = (m==1) ;
    bool isZeroByZero = (m==0)&&(n==0) ;
    return (isRowVector || isZeroByZero) ;
}


    
// Find the index in TASK_HANDLES of the given task handle.  Returns -1 if given
// task handle is not in TASK_HANDLES.
int32 findTaskByHandle(TaskHandle taskHandle)  {
    // Find the given taskHandle in the list of valid taskHandles, return -1 if can't find it
    int32 taskHandleIndex = -1 ;
    int32 i ;
    for ( i = 0 ; i < TASK_HANDLE_COUNT ; ++i )  {
        if ( taskHandle == TASK_HANDLES[i] )  {
            taskHandleIndex = i ;
            break ;
        }
    }
    return taskHandleIndex ;
}
    


// Utility to clear the task at the indicated index in TASK_HANDLES.  
// Won't throw a Matlab error, but returns a NI-style status code.
// Doesn't let a warning stop it from removing an item from TASK_HANDLES.
int32 clearTaskByIndex(int32 taskHandleIndex)  {
    int32 status ;

    mexPrintf("Just entered clearTaskByIndex, with taskHandleIndex = %d\n", taskHandleIndex) ;
    if ( 0 <= taskHandleIndex && taskHandleIndex < TASK_HANDLE_COUNT )  {
        TaskHandle taskHandle = TASK_HANDLES[taskHandleIndex] ;
        status = DAQmxClearTask(taskHandle);
        if ( status >= 0 )  {  // Even if a warning, still remove the task from TASK_HANDLES
            // Remove it from the list, shifting tasks after it one left
            int32 i ;
            for ( i = taskHandleIndex ; i < (TASK_HANDLE_COUNT-1) ; ++i )  {
                TASK_HANDLES[i] = TASK_HANDLES[i+1] ;
            }
            TASK_HANDLES[TASK_HANDLE_COUNT-1] = 0 ;  // For tidyness
            
            // Decrement the task handle count
            --TASK_HANDLE_COUNT ;
        }
    }    
    else {
        // the taskHandleIndex was bad, but we'll just ignore that
        status = 0 ;
    }
        
    return status ;
}



// Utility to clear tasks: Won't generate a Matlab error, but returns a NI-style
// status code indicating success/failure.  Ignores NI warnings.
int32 clearAllTasks(void)  {
    int32 status = 0 ;  // Used several places for DAQmx return codes
    int32 taskHandleIndex ;

    // Delete each task, last to first
    //for ( taskHandleIndex=0 ; taskHandleIndex<TASK_HANDLE_COUNT ; ++taskHandleIndex)  {
    for (taskHandleIndex=(TASK_HANDLE_COUNT-1); taskHandleIndex>=0; --taskHandleIndex)  {  // faster
        int32 thisStatus = clearTaskByIndex(taskHandleIndex) ;
        if ( thisStatus < 0 )  {  // ignore warnings but not errors
            status = thisStatus ;
        }
    }
    
    return status ;
}
// end of function



// This will be registered with mexAtExit()
static void finalize(void)  {
    // Clear all the tasks
    clearAllTasks() ;  // Ignore return value, b/c can't do anything about it anyway
    
    // It's now safe to clear the DLL from memory
    mexUnlock() ;
}
// end of function



// This is called if the entry point is unlocked        
static void initialize(void)  {
    mexLock() ;
        // Don't clear the DLL on exit, to preserve the list of valid task handles
    mexAtExit(&finalize) ;
        // Makes it so if this mex function gets cleared, all the tasks will be cleared from DAQmx
}

    

// taskHandle = DAQmxTaskMaster_('DAQmxCreateTask', taskName)
void CreateTask(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    char *taskName ;
    mxArray *taskHandleMXArray ;
    TaskHandle *taskHandlePtr ;
    //mwSize i ;

    if ( TASK_HANDLE_COUNT == MAXIMUM_TASK_HANDLE_COUNT )  {
        mexErrMsgIdAndTxt("ws:ni:tooManyTasks",
                          "Unable to create new DAQmx task, because the maximum number of tasks already exist") ;
    }    
    
    // prhs[1]: taskName
    taskName = readStringArgument(nrhs, prhs, 1, "taskName", EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED) ;

    //mexPrintf("Point 2\n");

    // Create the task
    status = DAQmxCreateTask(taskName, &taskHandle) ;
    handlePossibleDAQmxErrorOrWarning(status); 

    //mexPrintf("Point 3\n");

    // Register the taskHandle
    TASK_HANDLES[TASK_HANDLE_COUNT] = taskHandle ;
    ++TASK_HANDLE_COUNT ;

    // Allocate the output buffer
    taskHandleMXArray = mxCreateNumericMatrix(1, 1, mxUINT64_CLASS, mxREAL) ;

    // Set the output array contents
    //mexPrintf("About to set the data\n");
    taskHandlePtr = (TaskHandle *) mxGetData(taskHandleMXArray) ;
    *taskHandlePtr = taskHandle ;
    //mexPrintf("Just set the data\n");

    // Return output data
    plhs[0] = taskHandleMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        

    //mexPrintf("About to exit\n");
}
// end of function



// taskHandles = DAQmxGetAllTaskHandles()
void GetAllTaskHandles(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    //int32 status ;  // Used several places for DAQmx return codes
    //TaskHandle taskHandle ;
    //mxArray *taskHandleMXArray ;
    //TaskHandle *taskHandlePtr ;
    //mwSize i ;

    mxArray* taskHandleMXArray = mxCreateNumericMatrix(1, TASK_HANDLE_COUNT, mxUINT64_CLASS, mxREAL) ;
    uInt64* taskHandleMxArrayStoragePointer = (uInt64*)(mxGetData(taskHandleMXArray)) ;
    
    mwSize i ;
    for (i=0; i<TASK_HANDLE_COUNT; ++i)  {
        taskHandleMxArrayStoragePointer[i] = (uInt64)(TASK_HANDLES[i]) ;
    }
    
    // Return output data
    plhs[0] = taskHandleMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        

    //mexPrintf("About to exit\n");
}
// end of function



// DAQmxClearTask(taskHandle)
void ClearTask(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;

    mwSize i ;
    //int didFindJustClearedTask, didNotSucceed ;  // Used as boolean
    //uInt64 taskHandleAsUint64 ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;
        // This will error out if there are zero registered tasks
    
    // Find the index of the task handle
    int taskHandleIndex = findTaskByHandle(taskHandle) ;
    if ( taskHandleIndex < 0 )  {
        mexErrMsgIdAndTxt("ws:ni:BadArgument", "Not a valid task handle");
    }
    
    // Clear the task
    status = clearTaskByIndex(taskHandleIndex) ;
    handlePossibleDAQmxErrorOrWarning(status);
    
    // If get here, task was successfully un-registered                    
}



// DAQmxClearAllTasks()
void ClearAllTasks(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status = clearAllTasks() ;
    handlePossibleDAQmxErrorOrWarning(status);
}



// DAQmxStartTask(taskHandle)
void StartTask(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxStartTask(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxStopTask(taskHandle)
void StopTask(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;

    //
    // Read input arguments
    //

    // prhs[0]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxStopTask(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxTaskControl(taskHandle, action)
void TaskControl(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    int32 action ;

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: action
    action = readValueArgument(nrhs, prhs, 
                               2, "action") ;

    // Make the call
    status = DAQmxTaskControl(taskHandle, action) ;
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCfgDigEdgeStartTrig(taskHandle, triggerSource, triggerEdge)
void CfgDigEdgeStartTrig(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    char *triggerSource ;
    int32 triggerEdge ;
    int index ;

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: triggerSource
    index=2 ;
    triggerSource = readStringArgument(nrhs, prhs, 
                                       index, "triggerSource", 
                                       EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED);

    // prhs[3]: triggerEdge
    index++ ;
    triggerEdge = readValueArgument(nrhs, prhs, 
                                    index, "triggerEdge") ;

    // Make the call
    status = DAQmxCfgDigEdgeStartTrig(taskHandle, triggerSource, triggerEdge) ;
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCfgSampClkTiming(taskHandle,source,rate,activeEdge,sampleMode,sampsPerChanToAcquire)
void CfgSampClkTiming(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    size_t index ;
    char *source ;
    int32 activeEdge ;
    int32 sampleMode ;
    uInt64 sampsPerChanToAcquire ;
    float64 rate ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: source
    // prhs[3]: rate
    // prhs[4]: activeEdge
    // prhs[5]: sampleMode
    // prhs[6]: sampsPerChanToAcquire

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: source
    source = readStringArgument(nrhs, prhs, 2, "source", EMPTY_IS_ALLOWED, MISSING_IS_ALLOWED);

    // prhs[3]: rate
    if ( nrhs>3 && mxIsScalar(prhs[3]) && mxIsNumeric(prhs[3]) )
        {
        rate = (float64) mxGetScalar(prhs[3]) ;
        }
    else
        {
        mexErrMsgTxt("rate must be a numeric scalar");        
        }

    // prhs[4]: activeEdge
    index=4 ;
    activeEdge = 
        readValueArgument(nrhs, prhs, 
                          index, "activeEdge") ;

    // prhs[5]: sampleMode
    index++ ;
    sampleMode = 
        readValueArgument(nrhs, prhs, 
                          index, "sampleMode") ;

    // prhs[6]: sampsPerChannelToAcquire
    index++ ;
    if ( nrhs>index && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) )
        {
        sampsPerChanToAcquire = (uInt64) mxGetScalar(prhs[index]) ;
        }
    else
        {
        mexErrMsgTxt("sampsPerChannelToAcquire must be a numeric scalar");        
        }

    //
    // Call it in
    //
    status = DAQmxCfgSampClkTiming(taskHandle, 
                                   source,
                                   rate, 
                                   activeEdge, 
                                   sampleMode,
                                   sampsPerChanToAcquire);
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCreateAIVoltageChan(taskHandle, physicalChannelName)
void CreateAIVoltageChan(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    char *physicalChannelName ;
    int rc ;
    size_t nCharacters, bufferSize ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: physicalChannelName

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalChannelName
    if ( (nrhs>2) && mxIsChar(prhs[2]) )   {
        nCharacters = mxGetNumberOfElements(prhs[2]);
        if (nCharacters==0)   {
            mexErrMsgIdAndTxt("ws:ni:BadArgument","physicalChannelName cannot be empty");
        }
        bufferSize = nCharacters + 1 ;
        physicalChannelName = (char *)mxCalloc(bufferSize,sizeof(char));  
        rc = mxGetString(prhs[2], physicalChannelName, (mwSize)bufferSize);
        if (rc != 0)  {
            mexErrMsgIdAndTxt("ws:ni:InternalError","Problem getting physicalChannelName into a C string");
        }
    }
    else  {
        mexErrMsgIdAndTxt("ws:ni:BadArgument","physicalChannelName must be a string");
    }

    //
    // Make the call
    //
    status = DAQmxCreateAIVoltageChan(taskHandle,
                                      physicalChannelName, 
                                      NULL,
                                      DAQmx_Val_Cfg_Default, 
                                      -10.0, 
                                      +10.0, 
                                      DAQmx_Val_Volts, 
                                      NULL);
    handlePossibleDAQmxErrorOrWarning(status);
}
// end of function



// DAQmxCreateAOVoltageChan(taskHandle, physicalChannelName)
void CreateAOVoltageChan(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    char *physicalChannelName ;
    int rc ;
    size_t nCharacters, bufferSize ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: physicalChannelName

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalChannelName
    physicalChannelName = readStringArgument(nrhs, prhs, 
                                             2, "physicalChannelName" ,
                                             EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED) ;

    //
    // Make the call
    //
    status = DAQmxCreateAOVoltageChan(taskHandle,
                                      physicalChannelName, 
                                      NULL,
                                      -10.0, 
                                      +10.0, 
                                      DAQmx_Val_Volts, 
                                      NULL);
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCreateDIChan(taskHandle, physicalLineName)
//   physicalLineName should be something like 'Dev1/line0' or
//   'Dev1/line7', not something fancy like 'Dev1/port0' or
//   'Dev1/port0/line1' or a range, or any of that sort of thing
void CreateDIChan(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    char *physicalLineName ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalLineName
    physicalLineName = readStringArgument(nrhs, prhs, 2, "physicalLineName", 
                                          EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED);

    //
    // Make the call
    //
    status = DAQmxCreateDIChan(taskHandle, 
                               physicalLineName, 
                               NULL, 
                               DAQmx_Val_ChanPerLine) ;
    // Setting the third argument this way guarantees (I think) that
    // if you call DAQmxReadDigitalLines() later, it will always
    // return 1 for numBytesPerSamp.  This is nice b/c it means we
    // don't have to return that if/when we wrap DAQmxReadDigitalLines().
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCreateDOChan(taskHandle, physicalLineName)
//   physicalLineName should be something like 'Dev1/line0' or
//   'Dev1/line7', not something fancy like 'Dev1/port0' or
//   'Dev1/port0/line1' or a range, or any of that sort of thing
void CreateDOChan(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    char *physicalLineName ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalLineName
    physicalLineName = readStringArgument(nrhs, prhs, 2, "physicalLineName", 
                                          EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED);

    //
    // Make the call
    //
    status = DAQmxCreateDOChan(taskHandle, 
                               physicalLineName, 
                               NULL, 
                               DAQmx_Val_ChanPerLine) ;
    // Setting the third argument this way guarantees (I think) that
    // if you call DAQmxWriteDigitalLines() later, it will always
    // return 1 for numBytesPerSamp.  This is nice b/c it means we
    // don't have to return that if/when we wrap DAQmxWriteDigitalLines().
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// nSampsPerChanAvail = DAQmxGetReadAvailSampPerChan(taskHandle)
void GetReadAvailSampPerChan(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    uInt32 nSampsPerChanAvail ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxGetReadAvailSampPerChan(taskHandle, &nSampsPerChanAvail);
    handlePossibleDAQmxErrorOrWarning(status);

    // Return output data
    plhs[0] = mxCreateDoubleScalar((double)nSampsPerChanAvail) ;  
    }
// end of function



// isTaskDone = DAQmxIsTaskDone(taskHandle)
void IsTaskDone(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    bool32 isTaskDone ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxIsTaskDone(taskHandle, &isTaskDone);
    handlePossibleDAQmxErrorOrWarning(status);

    // Return output data
    plhs[0] = mxCreateLogicalScalar((mxLogical)isTaskDone) ;  
    }
// end of function



// outputData = DAQmxReadBinaryI16(taskHandle, nSampsPerChanWanted, timeout)
void ReadBinaryI16(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    int32 numSampsPerChanRequested ;  // this does take negative vals in the case of DAQmx_Val_Auto
    float64 timeout ;
    uInt32 numChannels; 
    int32 numSampsPerChanToTryToRead;
    uInt32 nSampsPerChanAvailable;
    //mxClassID outputDataClass = mxINT16_CLASS;
    mxArray *outputDataMXArray;
    uInt32 arraySizeInSamps;
    int16 *outputDataPtr;
    int32 numSampsPerChanRead;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: numSampsPerChanRequested
    // prhs[3]: timeout

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: numSampsPerChanRequested
    if ( (nrhs>2) && mxIsScalar(prhs[2]) )  
        {
        numSampsPerChanRequested = (int32) mxGetScalar(prhs[2]) ;
        }
    else 
        {
        mexErrMsgTxt("numSampsPerChanRequested must be a scalar");        
        }

    // prhs[3]: timeout
    timeout = readTimeoutArgument(nrhs, prhs, 3) ;
    
    // Determine # of channels
    status = DAQmxGetReadNumChans(taskHandle,&numChannels); 
    handlePossibleDAQmxErrorOrWarning(status);
    
    // Determine the number of samples to try to read.
    // If user has requested all the sample available, find out how many that is.
    if (numSampsPerChanRequested>=0) 
        {
        numSampsPerChanToTryToRead = numSampsPerChanRequested ;
        }        
    else            
        {
        // In this case, have to find out how many scans are available
        status = DAQmxGetReadAvailSampPerChan(taskHandle,&nSampsPerChanAvailable);
        handlePossibleDAQmxErrorOrWarning(status);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable ;
        }
    
    // Allocate the output buffer
    outputDataMXArray = 
        mxCreateNumericMatrix(numSampsPerChanToTryToRead,numChannels,mxINT16_CLASS,mxREAL);

    // Check that the array size is correct
    arraySizeInSamps = ((uInt32)numSampsPerChanToTryToRead) * numChannels ;
    if ( mxGetNumberOfElements(outputDataMXArray) != (size_t)(arraySizeInSamps) )
        {
        mexErrMsgTxt("Failed to allocate an output array of the desired size");    
        }

    // Get a pointer to the storage for the output buffer
    outputDataPtr = (int16 *)mxGetData(outputDataMXArray);

    // Read the data
    //mexPrintf("About to try to read %d scans of data\n", numSampsPerChanToTryToRead);
    // The daqmx reading functions complain if you call them when there's no more data to read, 
    // even if you ask for zero scans.
    // So we don't attempt a read if numSampsPerChanToTryToRead is zero.
    if (numSampsPerChanToTryToRead>0)  
        {
        status = DAQmxReadBinaryI16(taskHandle, 
                                    numSampsPerChanToTryToRead, 
                                    timeout, 
                                    DAQmx_Val_GroupByChannel, 
                                    outputDataPtr, 
                                    arraySizeInSamps, 
                                    &numSampsPerChanRead, 
                                    NULL);

        // Check for error during the read
        handlePossibleDAQmxErrorOrWarning(status);
        }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// coefficients = DAQmxGetAIDevScalingCoeff(taskHandle)
void GetAIDevScalingCoeff(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    int32 numSampsPerChanRequested ;  // this does take negative vals in the case of DAQmx_Val_Auto
    float64 timeout ;
    uInt32 numChannels; 
    int32 numSampsPerChanToTryToRead;
    uInt32 nSampsPerChanAvailable;
    //mxClassID outputDataClass = mxINT16_CLASS;
    mxArray *outputDataMXArray;
    uInt32 arraySizeInSamps;
    int16 *outputDataPtr;
    int32 numSampsPerChanRead;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: numSampsPerChanRequested
    // prhs[3]: timeout

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: numSampsPerChanRequested
    if ( (nrhs>2) && mxIsScalar(prhs[2]) )  
        {
        numSampsPerChanRequested = (int32) mxGetScalar(prhs[2]) ;
        }
    else 
        {
        mexErrMsgTxt("numSampsPerChanRequested must be a scalar");        
        }

    // prhs[3]: timeout
    timeout = readTimeoutArgument(nrhs, prhs, 3) ;
    
    // Determine # of channels
    status = DAQmxGetReadNumChans(taskHandle,&numChannels); 
    handlePossibleDAQmxErrorOrWarning(status);
    
    // Determine the number of samples to try to read.
    // If user has requested all the sample available, find out how many that is.
    if (numSampsPerChanRequested>=0) 
        {
        numSampsPerChanToTryToRead = numSampsPerChanRequested ;
        }        
    else            
        {
        // In this case, have to find out how many scans are available
        status = DAQmxGetReadAvailSampPerChan(taskHandle,&nSampsPerChanAvailable);
        handlePossibleDAQmxErrorOrWarning(status);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable ;
        }
    
    // Allocate the output buffer
    outputDataMXArray = 
        mxCreateNumericMatrix(numSampsPerChanToTryToRead,numChannels,mxINT16_CLASS,mxREAL);

    // Check that the array size is correct
    arraySizeInSamps = ((uInt32)numSampsPerChanToTryToRead) * numChannels ;
    if ( mxGetNumberOfElements(outputDataMXArray) != (size_t)(arraySizeInSamps) )
        {
        mexErrMsgTxt("Failed to allocate an output array of the desired size");    
        }

    // Get a pointer to the storage for the output buffer
    outputDataPtr = (int16 *)mxGetData(outputDataMXArray);

    // Read the data
    //mexPrintf("About to try to read %d scans of data\n", numSampsPerChanToTryToRead);
    // The daqmx reading functions complain if you call them when there's no more data to read, 
    // even if you ask for zero scans.
    // So we don't attempt a read if numSampsPerChanToTryToRead is zero.
    if (numSampsPerChanToTryToRead>0)  
        {
        status = DAQmxReadBinaryI16(taskHandle, 
                                    numSampsPerChanToTryToRead, 
                                    timeout, 
                                    DAQmx_Val_GroupByChannel, 
                                    outputDataPtr, 
                                    arraySizeInSamps, 
                                    &numSampsPerChanRead, 
                                    NULL);

        // Check for error during the read
        handlePossibleDAQmxErrorOrWarning(status);
        }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// outputData = DAQmxReadDigitalLines(taskHandle, nSampsPerChanWanted, timeout)
void ReadDigitalLines(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    int32 numSampsPerChanWanted ;  // this does take negative vals in the case of DAQmx_Val_Auto
    float64 timeout ;
    uInt32 numChannels; 
    int32 numSampsPerChanToTryToRead;
    uInt32 nSampsPerChanAvailable;
    //mxClassID outputDataClass = mxINT16_CLASS;
    mxArray *outputDataMXArray;
    uInt32 arraySizeInSamps;
    uInt8 *outputDataPtr;
    int32 numSampsPerChanRead;
    int32 numBytesPerSamp ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: numSampsPerChanWanted
    // prhs[3]: timeout

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: numSampsPerChanWanted
    if ( (nrhs>2) && mxIsScalar(prhs[2]) )  
        {
        numSampsPerChanWanted = (int32) mxGetScalar(prhs[2]) ;
        }
    else 
        {
        mexErrMsgIdAndTxt("ws:ni:badArgument","numSampsPerChanWanted must be a scalar");        
        }

    // prhs[3]: timeout
    timeout = readTimeoutArgument(nrhs, prhs, 3) ;
    
    // Determine the number of samples to try to read.
    // If user has requested all the sample available, find out how many that is.
    if (numSampsPerChanWanted>=0) 
        {
        numSampsPerChanToTryToRead = numSampsPerChanWanted ;
        }        
    else            
        {
        // In this case, have to find out how many scans are available
        status = DAQmxGetReadAvailSampPerChan(taskHandle,&nSampsPerChanAvailable);
        handlePossibleDAQmxErrorOrWarning(status);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable ;
        }
    
    // Determine # of channels
    status = DAQmxGetReadNumChans(taskHandle,&numChannels); 
    handlePossibleDAQmxErrorOrWarning(status);
    
    // Allocate the output buffer
    outputDataMXArray = 
        mxCreateLogicalMatrix(numSampsPerChanToTryToRead,numChannels);

    // Check that the array size is correct
    arraySizeInSamps = (uInt32) (numSampsPerChanToTryToRead * numChannels) ;
    if ( mxGetNumberOfElements(outputDataMXArray) != (size_t)(arraySizeInSamps) )
        {
        mexErrMsgIdAndTxt("ws:ni:failedToAllocateMemory",
                          "Failed to allocate an output array of the desired size");    
        }

    // Get a pointer to the storage for the output buffer
    outputDataPtr = (uInt8 *)mxGetData(outputDataMXArray);

    // Read the data
    // The daqmx reading functions complain if you call them when there's no more data to read, 
    // even if you ask for zero scans.
    // So we don't attempt a read if numSampsPerChanToTryToRead is zero.
    if (numSampsPerChanToTryToRead>0)  
        {
        status = DAQmxReadDigitalLines(taskHandle, 
                                       numSampsPerChanToTryToRead, 
                                       timeout, 
                                       DAQmx_Val_GroupByChannel, 
                                       outputDataPtr, 
                                       arraySizeInSamps, 
                                       &numSampsPerChanRead,
                                       &numBytesPerSamp,
                                       NULL);

        // Check for error during the read
        handlePossibleDAQmxErrorOrWarning(status);

        // If things are as we expect, numBytesPerSamp should *always* be one
        if ( numBytesPerSamp != 1)
            {
            mexErrMsgIdAndTxt("ws:ni:numBytesPerSampIsWrong",
                              "numBytesPerSamp is %d, it should be one",numBytesPerSamp);        
            }
        }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// outputData = DAQmxReadDigitalU32(taskHandle, nSampsPerChanWanted, timeout)
void ReadDigitalU32(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    int32 numSampsPerChanWanted ;  // this does take negative vals in the case of DAQmx_Val_Auto
    float64 timeout ;
    uInt32 numChannels; 
    int32 numSampsPerChanToTryToRead;
    uInt32 nSampsPerChanAvailable;
    //mxClassID outputDataClass = mxINT16_CLASS;
    mxArray *outputDataMXArray;
    uInt32 arraySizeInSamps;
    int16 *outputDataPtr;
    int32 numSampsPerChanRead;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    // prhs[2]: numSampsPerChanWanted
    // prhs[3]: timeout

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: numSampsPerChanWanted
    if ( (nrhs>2) && mxIsScalar(prhs[2]) )  
        {
        numSampsPerChanWanted = (int32) mxGetScalar(prhs[2]) ;
        }
    else 
        {
        mexErrMsgTxt("numSampsPerChanWanted must be a scalar");        
        }

    // prhs[3]: timeout
    timeout = readTimeoutArgument(nrhs, prhs, 3) ;
    
    // Determine the number of samples to try to read.
    // If user has requested all the sample available, find out how many that is.
    if (numSampsPerChanWanted>=0) 
        {
        numSampsPerChanToTryToRead = numSampsPerChanWanted ;
        }        
    else            
        {
        // In this case, have to find out how many scans are available
        status = DAQmxGetReadAvailSampPerChan(taskHandle,&nSampsPerChanAvailable);
        handlePossibleDAQmxErrorOrWarning(status);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable ;
        }
    
    // Allocate the output buffer
    outputDataMXArray = 
        mxCreateNumericMatrix(numSampsPerChanToTryToRead,1,mxUINT32_CLASS,mxREAL);

    // Check that the array size is correct
    arraySizeInSamps = (uInt32) numSampsPerChanToTryToRead ;
    if ( mxGetNumberOfElements(outputDataMXArray) != (size_t)(arraySizeInSamps) )
        {
        mexErrMsgTxt("Failed to allocate an output array of the desired size");    
        }

    // Get a pointer to the storage for the output buffer
    outputDataPtr = (uInt32 *)mxGetData(outputDataMXArray);

    // Read the data
    //mexPrintf("About to try to read %d scans of data\n", numSampsPerChanToTryToRead);
    // The daqmx reading functions complain if you call them when there's no more data to read, 
    // even if you ask for zero scans.
    // So we don't attempt a read if numSampsPerChanToTryToRead is zero.
    if (numSampsPerChanToTryToRead>0)  
        {
        status = DAQmxReadDigitalU32(taskHandle, 
                                     numSampsPerChanToTryToRead, 
                                     timeout, 
                                     DAQmx_Val_GroupByChannel, 
                                     outputDataPtr, 
                                     arraySizeInSamps, 
                                     &numSampsPerChanRead, 
                                     NULL);

        // Check for error during the read
        handlePossibleDAQmxErrorOrWarning(status);
        }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// DAQmxWaitUntilTaskDone(taskHandle, timeToWait)
void WaitUntilTaskDone(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    float64 timeToWait ;
    int index ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: timeToWait
    index=2 ;
    if (nrhs>index)  {
        if ( mxIsEmpty(prhs[index]) )   {
            timeToWait = DAQmx_Val_WaitInfinitely ;
        }
        else if ( mxIsScalar(prhs[index]) )   {
            timeToWait = (float64) mxGetScalar(prhs[index]) ;
            if (timeToWait==-1.0 || timeToWait>=0)  {
                if ( isfinite(timeToWait) )  {
                    // do nothing, all is well
                }
                else  {
                    timeToWait = DAQmx_Val_WaitInfinitely ;
                }
            }
            else  {
                mexErrMsgTxt("timeToWait must be DAQmx_Val_WaitInfinitely (-1), 0, or positive");
            }
        }
        else  {
            mexErrMsgTxt("timeToWait must be a missing, empty, or a scalar");        
        }
    }
    else  {
        timeToWait = DAQmx_Val_WaitInfinitely ;
    }

    //
    // Make the call
    status = DAQmxWaitUntilTaskDone(taskHandle,timeToWait) ; 
    handlePossibleDAQmxErrorOrWarning(status);
}



// sampsPerChanWritten = DAQmxWriteAnalogF64(taskHandle, autoStart, timeout, writeArray)
void WriteAnalogF64(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    int index ; // index of the input arg we're currently dealing with
    TaskHandle taskHandle ;
    bool32 autoStart ;
    float64 timeout ;
    float64 *writeArray ;
    size_t nSampsPerChan ;
    size_t nChannelsInWriteArray ;
    uInt32 nChannelsInTask ;
    int32 nSampsPerChanWritten ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: autoStart
    index = 2;
    if ( (nrhs>index) && mxIsScalar(prhs[index]) )  
        {
        autoStart = (bool32) mxGetScalar(prhs[index]) ;
        }
    else 
        {
        mexErrMsgTxt("autoStart must be a scalar");        
        }

    // prhs[3]: timeout
    index++;
    timeout = readTimeoutArgument(nrhs, prhs, index) ;
    
    // prhs[4]: writeArray
    index++;
    if (nrhs>index && mxIsDouble(prhs[index]) && !mxIsComplex(prhs[index]) &&
        mxGetNumberOfDimensions(prhs[index])==2 )
        {
        nSampsPerChan = mxGetM(prhs[index]) ;
        nChannelsInWriteArray = mxGetN(prhs[index]) ;
        writeArray = (float64 *)mxGetData(prhs[index]) ;
        }
    else
        {
        mexErrMsgIdAndTxt("ws:ni:badArgument","writeArray must be an matrix of real doubles");        
        }

    // Determine # of channels in task
    status = DAQmxGetWriteNumChans(taskHandle,&nChannelsInTask); 
    handlePossibleDAQmxErrorOrWarning(status);

    // Verify the number of channels in the task equals that in the writeArray
    //mexPrintf("nChannelsInTask: %d\n",nChannelsInTask) ;
    //mexPrintf("nChannelsInWriteArray: %d\n",nChannelsInWriteArray) ;    
    if (nChannelsInTask != nChannelsInWriteArray)
        {
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          "writeArray must have the same number of columns as the task has channels");
        }

    //
    // Make the call
    // 
    status = DAQmxWriteAnalogF64(taskHandle, 
                                 nSampsPerChan,
                                 autoStart,
                                 timeout, 
                                 DAQmx_Val_GroupByChannel,
                                 writeArray,
                                 &nSampsPerChanWritten, 
                                 NULL);
    handlePossibleDAQmxErrorOrWarning(status);

    // Return output data
    plhs[0] = mxCreateDoubleScalar(nSampsPerChanWritten) ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// sampsPerChanWritten = DAQmxWriteDigitalLines(taskHandle, autoStart, timeout, writeArray)
void WriteDigitalLines(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    int index ; // index of the input arg we're currently dealing with
    TaskHandle taskHandle ;
    bool32 autoStart ;
    float64 timeout ;
    uInt8 *writeArray ;
    size_t nSampsPerChan ;
    size_t nChannelsInWriteArray ;
    uInt32 nChannelsInTask ;
    int32 nSampsPerChanWritten ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: autoStart
    index = 2;
    if ( (nrhs>index) && mxIsScalar(prhs[index]) )  
        {
        autoStart = (bool32) mxGetScalar(prhs[index]) ;
        }
    else 
        {
        mexErrMsgTxt("autoStart must be a scalar");        
        }

    // prhs[3]: timeout
    index++;
    timeout = readTimeoutArgument(nrhs, prhs, index) ;
    
    // prhs[4]: writeArray
    index++;
    if ( nrhs>index && mxIsLogical(prhs[index]) && mxGetNumberOfDimensions(prhs[index])==2 )
        {
        nSampsPerChan = mxGetM(prhs[index]) ;
        nChannelsInWriteArray = mxGetN(prhs[index]) ;
        writeArray = (uInt8 *)mxGetData(prhs[index]) ;
        }
    else
        {
        mexErrMsgIdAndTxt("ws:ni:badArgument","writeArray must be a matrix of class logical");        
        }

    // Determine # of channels in task
    status = DAQmxGetWriteNumChans(taskHandle,&nChannelsInTask); 
    handlePossibleDAQmxErrorOrWarning(status);

    // Verify the number of channels in the task equals that in the writeArray
    //mexPrintf("nChannelsInTask: %d\n",nChannelsInTask) ;
    //mexPrintf("nChannelsInWriteArray: %d\n",nChannelsInWriteArray) ;    
    if (nChannelsInTask != nChannelsInWriteArray)
        {
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          "writeArray must have the same number of columns as the task has channels");
        }

    //
    // Make the call
    // 
    status = DAQmxWriteDigitalLines(taskHandle, 
                                    nSampsPerChan,
                                    autoStart,
                                    timeout, 
                                    DAQmx_Val_GroupByChannel,
                                    writeArray,
                                    &nSampsPerChanWritten, 
                                    NULL);
    handlePossibleDAQmxErrorOrWarning(status);

    // Return output data
    plhs[0] = mxCreateDoubleScalar(nSampsPerChanWritten) ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }
// end of function



// The entry-point, where we do dispatch
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // Dispatch on the 'method' name
    if (nrhs<1)  {
        mexErrMsgIdAndTxt("DAQmxTaskMaster_:tooFewArguments",
                          "DAQmxTaskMaster_() needs at least one argument") ;
    }
    
    const mxArray* actionAsMxArray = (mxArray*)(prhs[0]) ;
    if (!isMxArrayAString(actionAsMxArray))  {
        mexErrMsgIdAndTxt("DAQmxTaskMaster_:argNotAString", 
                          "First argument to DAQmxTaskMaster_() must be a string.") ;        
    }

    // Keep the DLL in memory after exit, so that this function acts as a poor man's 
    // Singleton object, and we can keep a list of the valid task handles
    if (!mexIsLocked())  {
        initialize() ;
    }   
    
    // Dispatch on the method name
    char* action = mxArrayToString(actionAsMxArray) ;  // Do I need to free this?
    if ( strcmp(action,"DAQmxCreateTask")==0 )  {
        CreateTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxGetAllTaskHandles")==0 )  {
        GetAllTaskHandles(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxClearTask")==0 )  {
        ClearTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxClearAllTasks")==0 )  {
        ClearAllTasks(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxStartTask")==0 )  {
        StartTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxStopTask")==0 )  {
        StopTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxTaskControl")==0 )  {
        TaskControl(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxCreateAIVoltageChan")==0 )  {
        CreateAIVoltageChan(nlhs, plhs, nrhs, prhs) ;
    }    
    else if ( strcmp(action,"DAQmxCreateAOVoltageChan")==0 )  {
        CreateAOVoltageChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxCreateDIChan")==0 )  {
        CreateDIChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxCreateDOChan")==0 )  {
        CreateDOChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxGetReadAvailSampPerChan")==0 )  {
        GetReadAvailSampPerChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxIsTaskDone")==0 )  {
        IsTaskDone(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxReadBinaryI16")==0 )  {
        ReadBinaryI16(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxReadDigitalLines")==0 )  {
        ReadDigitalLines(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxReadDigitalU32")==0 )  {
        ReadDigitalU32(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxWaitUntilTaskDone")==0 )  {
        WaitUntilTaskDone(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxWriteAnalogF64")==0 )  {
        WriteAnalogF64(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxWriteDigitalLines")==0 )  {
        WriteDigitalLines(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxCfgSampClkTiming")==0 )  {
        CfgSampClkTiming(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxCfgDigEdgeStartTrig")==0 )  {
        CfgDigEdgeStartTrig(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"DAQmxGetAIDevScalingCoeff")==0 )  {
        GetAIDevScalingCoeff(nlhs, plhs, nrhs, prhs) ;
    }
    else  {
        // Doesn't match anything, so error
        mexErrMsgIdAndTxt("ws:ni:noSuchMethod",
                          "DAQmxTaskMaster_() doesn't recognize that method name") ;
    }

    //mexPrintf("About to exit\n");
}
// end of function

