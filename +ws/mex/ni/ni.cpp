#include <string>
#include <vector>
#include <limits> 
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
int32 TASK_HANDLE_COUNT = 0 ;



#define isfinite(x) ( _finite(x) )        // MSVC-specific, change as needed



void 
handlePossibleDAQmxErrorOrWarning(int32 errorCode)  {
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



std::pair<bool, std::string>
readStringArgument(int nrhs, const mxArray *prhs[], 
                   int index, const std::string & argumentName, 
                   int isEmptyAllowed, int isMissingAllowed)  {
    std::pair<bool, std::string> result ;

    if (nrhs<index+1)  {
        // Arg is missing
        if (isMissingAllowed)  {
            result = std::make_pair(false, "") ;
        }
        else  {
            mexErrMsgIdAndTxt("ws:ni:BadArgument","%s cannot be missing",argumentName);
        }
    }
    else  {
        // Arg exists
        if ( mxIsEmpty(prhs[index]) )  {
            if (isEmptyAllowed)  {
                result = std::make_pair(true, "");
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
                char * resultAsCharPtr = mxArrayToString(prhs[index]) ;  // Do I need to free this?  Yes, with mxFree()
                result = std::make_pair(true, resultAsCharPtr) ;
                mxFree(resultAsCharPtr) ;
                //if (!result)  {
                //    mexErrMsgIdAndTxt("ws:ni:InternalError", "Problem getting %s into a C string", argumentName.c_str());
                //}
            }
        }
    }

    return result ;
}
// end of function



std::string
readMandatoryStringArgument(int nrhs, const mxArray *prhs[],
                            int index, const std::string & argumentName,
                            int isEmptyAllowed) {
    std::string result;

    if (nrhs<index + 1) {
        // Arg is missing
        mexErrMsgIdAndTxt("ws:ni:BadArgument", "%s cannot be missing", argumentName);
    }
    else {
        // Arg exists
        if (mxIsEmpty(prhs[index])) {
            if (isEmptyAllowed) {
                result = "" ;
            }
            else {
                mexErrMsgIdAndTxt("ws:ni:BadArgument", "%s cannot be empty", argumentName);
            }
        }
        else {
            // Arg exists, is nonempty
            if (!mxIsChar(prhs[index])) {
                mexErrMsgIdAndTxt("ws:ni:BadArgument", "%s must be a string", argumentName);
            }
            else {
                // Arg exists, is nonempty, is a char array
                char * resultAsCharPtr = mxArrayToString(prhs[index]);  // Do I need to free this?  Yes, with mxFree()
                result = resultAsCharPtr ;
                mxFree(resultAsCharPtr);
                //if (!result)  {
                //    mexErrMsgIdAndTxt("ws:ni:InternalError", "Problem getting %s into a C string", argumentName.c_str());
                //}
            }
        }
    }

    return result;
}
// end of function



float64
readTimeoutArgument(int nrhs, const mxArray *prhs[], int index)  {
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
std::pair<bool, int32>
daqmxValueFromString(const std::string & valueAsString)  {
    std::pair<bool, int32> resultMaybe ;
    // Dispatch on the method name
    if ( valueAsString == "DAQmx_Val_ContSamps" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_ContSamps) ;
    }
    else if ( valueAsString == "DAQmx_Val_Falling" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Falling) ;
    }
    else if ( valueAsString == "DAQmx_Val_FiniteSamps" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_FiniteSamps) ;
    }
    else if ( valueAsString == "DAQmx_Val_Rising" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Rising) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Abort" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Abort) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Commit" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Commit) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Reserve" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Reserve) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Start" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Start) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Stop" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Stop) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Unreserve" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Unreserve) ;
    }
    else if ( valueAsString == "DAQmx_Val_Task_Verify" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Verify) ;
    }
    else if (valueAsString == "DAQmx_Val_Task_Verify") {
        resultMaybe = std::make_pair(true, DAQmx_Val_Task_Verify);
    }
    else if (valueAsString == "DAQmx_Val_ChanPerLine") {
        resultMaybe = std::make_pair(true, DAQmx_Val_ChanPerLine);
    }    
    else if (valueAsString == "DAQmx_Val_ChanForAllLines") {
        resultMaybe = std::make_pair(true, DAQmx_Val_ChanForAllLines);
    }
    else  {
        // Doesn't match anything, so result is empty
        resultMaybe = std::make_pair(false, 0);
    }
    return resultMaybe ;
}


int32
readValueArgument(int nrhs, const mxArray *prhs[], 
                  int index, const std::string & argumentName)  {
    std::string valueAsString = 
        readMandatoryStringArgument(nrhs, prhs, 
                                    index, argumentName, 
                                    EMPTY_IS_NOT_ALLOWED) ;  // This will not return if arg is missing
    std::pair<bool, int32> resultMaybe = daqmxValueFromString(valueAsString) ;
    if (!resultMaybe.first)  {
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          "Did not recognize value %s for argument %s", valueAsString.c_str(), argumentName);
    }

    int32 result = resultMaybe.second ;
    return result ;
}

    

// Helper function for reading a task handle argument and validating it
TaskHandle
readTaskHandleArgument(int nrhs, const mxArray *prhs[])  {
    TaskHandle taskHandle = 0 ;
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


    
// Find the index in TASK_HANDLES of the given task handle.  Returns int32,
// which is -1 if the handle is not found.
int32
findTaskByHandle(TaskHandle taskHandle)  {
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
int32
clearTaskByIndex(int32 taskHandleIndex)  {
    int32 status ;

    //mexPrintf("Just entered clearTaskByIndex, with taskHandleIndex = %d\n", taskHandleIndex) ;
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
int32
clearAllTasks(void)  {
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
static void
initialize(void)  {
    mexLock() ;
        // Don't clear the DLL on exit, to preserve the list of valid task handles
    mexAtExit(&finalize) ;
        // Makes it so if this mex function gets cleared, all the tasks will be cleared from DAQmx
}

    

// taskHandle = DAQmxTaskMaster_('DAQmxCreateTask', taskName)
void
CreateTask(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    mxArray *taskHandleMXArray ;
    TaskHandle *taskHandlePtr ;
    //mwSize i ;

    if ( TASK_HANDLE_COUNT == MAXIMUM_TASK_HANDLE_COUNT )  {
        mexErrMsgIdAndTxt("ws:ni:tooManyTasks",
                          "Unable to create new DAQmx task, because the maximum number of tasks already exist") ;
    }    
    
    // prhs[1]: taskName
    std::pair<bool, std::string> taskNameMaybe( readStringArgument(nrhs, prhs, 1, "taskName", EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED) ) ;
    std::string taskName(taskNameMaybe.second) ;

    //mexPrintf("Point 2\n");

    // Create the task
    status = DAQmxCreateTask(taskName.c_str(), &taskHandle) ;
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
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;
        // This will error out if there are zero registered tasks
    
    // Find the index of the task handle
    int taskHandleIndex = findTaskByHandle(taskHandle) ;
    if ( taskHandleIndex < 0 )  {
        mexErrMsgIdAndTxt("ws:ni:BadArgument", "Not a valid task handle");
    }
    
    // Clear the task
    int32 status;  // Used several places for DAQmx return codes
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
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: triggerSource
    int index=2 ;
    std::pair<bool, std::string> triggerSourceMaybe ( 
        readStringArgument(nrhs, prhs, 
                           index, "triggerSource", 
                           EMPTY_IS_NOT_ALLOWED, MISSING_IS_NOT_ALLOWED) ) ;
    std::string triggerSource(triggerSourceMaybe.second) ;

    // prhs[3]: triggerEdge
    index++ ;
    int32 triggerEdge;
    triggerEdge = readValueArgument(nrhs, prhs,
                                    index, "triggerEdge") ;

    // Make the call
    int32 status ;
    status = DAQmxCfgDigEdgeStartTrig(taskHandle, triggerSource.c_str(), triggerEdge) ;
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCfgSampClkTiming(taskHandle,source,rate,activeEdge,sampleMode,sampsPerChanToAcquire)
void CfgSampClkTiming(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // prhs[1]: taskHandle
    // prhs[2]: source
    // prhs[3]: rate
    // prhs[4]: activeEdge
    // prhs[5]: sampleMode
    // prhs[6]: sampsPerChanToAcquire

    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: source
    std::pair<bool, std::string> sourceMaybe( readStringArgument(nrhs, prhs, 2, "source", EMPTY_IS_ALLOWED, MISSING_IS_ALLOWED) ) ;

    // prhs[3]: rate
    float64 rate;
    if ( nrhs>3 && mxIsScalar(prhs[3]) && mxIsNumeric(prhs[3]) )  {
        rate = (float64) mxGetScalar(prhs[3]) ;
    }   
    else {
        mexErrMsgTxt("rate must be a numeric scalar");        
    }

    // prhs[4]: activeEdge
    int index=4 ;
    int32 activeEdge =
        readValueArgument(nrhs, prhs, 
                          index, "activeEdge") ;

    // prhs[5]: sampleMode
    index++ ;
    int32 sampleMode =
        readValueArgument(nrhs, prhs, 
                          index, "sampleMode") ;

    // prhs[6]: sampsPerChannelToAcquire
    index++ ;
    uInt64 sampsPerChanToAcquire;
    if ( nrhs>index && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) )  {
        sampsPerChanToAcquire = (uInt64) mxGetScalar(prhs[index]) ;
    }
    else  {
        mexErrMsgTxt("sampsPerChannelToAcquire must be a numeric scalar");        
    }

    // Call it in
    int32 status;
    const char * sourceArgument = (sourceMaybe.first ? sourceMaybe.second.c_str() : NULL) ;
    status = DAQmxCfgSampClkTiming(taskHandle,
                                   sourceArgument,
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
    char *physicalChannelName = 0 ;
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
    // prhs[1]: taskHandle
    // prhs[2]: physicalChannelName

    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalChannelName
    std::string physicalChannelName( readMandatoryStringArgument(nrhs, prhs, 
                                                                 2, "physicalChannelName" ,
                                                                 EMPTY_IS_NOT_ALLOWED) ) ;

    // Make the call
    int32 status;
    status = DAQmxCreateAOVoltageChan(taskHandle,
                                      physicalChannelName.c_str(), 
                                      NULL,
                                      -10.0, 
                                      +10.0, 
                                      DAQmx_Val_Volts, 
                                      NULL);
    handlePossibleDAQmxErrorOrWarning(status);
    }
// end of function



// DAQmxCreateDIChan(taskHandle, physicalLineName, lineGrouping)
//   physicalLineName should be something like 'Dev1/line0' or
//   'Dev1/line7', not something fancy like 'Dev1/port0' or
//   'Dev1/port0/line1' or a range, or any of that sort of thing
void CreateDIChan(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalLineName
    std::string physicalLineName( readMandatoryStringArgument(nrhs, prhs, 2, "physicalLineName", 
                                                              EMPTY_IS_NOT_ALLOWED) ) ;

    // prhs[2]: lineGrouping
    int32 lineGrouping = readValueArgument(nrhs, prhs, 3, "lineGrouping");

    // Make the call
    int32 status;
    status = DAQmxCreateDIChan(taskHandle,
                               physicalLineName.c_str(), 
                               NULL, 
                               lineGrouping) ;
    // Setting the fourth argument to DAQmx_Val_ChanPerLine guarantees (I think) that
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

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: physicalLineName
    std::string physicalLineName(readMandatoryStringArgument(nrhs, prhs, 2, "physicalLineName",
                                                             EMPTY_IS_NOT_ALLOWED));

    //
    // Make the call
    //
    status = DAQmxCreateDOChan(taskHandle, 
                               physicalLineName.c_str(), 
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
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // Make the call
    int32 status;
    bool32 isTaskDone;
    status = DAQmxIsTaskDone(taskHandle, &isTaskDone);
    handlePossibleDAQmxErrorOrWarning(status);

    // Return output data
    plhs[0] = mxCreateLogicalScalar(isTaskDone?true:false) ;  // Using tenary op prevents warning
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



// Trim whitespace from either end of a string
std::string 
trim(const std::string & s) {
    std::string::const_iterator it = s.begin();
    while (it != s.end() && isspace(*it)) {
        it++;
    }

    std::string::const_reverse_iterator rit = s.rbegin();
    while (rit.base() != it && isspace(*rit)) {
        rit++;
    }

    return std::string(it, rit.base());
}



// Parse a comma-separated list of channel names into a vector of strings, with one channel 
// name per element
std::vector<std::string>
parseListOfChannelNames(const std::string & listOfChannelNames) {
    // Input should be a comma-separated list of channel names, e.g.
    // "Dev1/ai0, Dev1/ai1".  Returns a vector of strings, with one 
    // channel name per string.

    int commaCount = int(std::count(listOfChannelNames.begin(), listOfChannelNames.end(), ','));
    int channelCount = commaCount + 1;
    std::vector<std::string> result(channelCount);
    size_t startPosition = 0;
    for (int i = 0; i < channelCount; ++i) {
        size_t endPosition = listOfChannelNames.find(',', startPosition);  // returns end-of-string when ',' not found
        std::string raw = listOfChannelNames.substr(startPosition, endPosition - startPosition);
        result[i] = trim(raw);
        // Prepare for next iteration
        startPosition = endPosition;
    }

    return result;
}



// coefficients = DAQmxGetAIDevScalingCoeffs(taskHandle)
void GetAIDevScalingCoeffs(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // All X series devices seem to return 4 coefficients
    // Simulated X series return 2, but we just fill in the rest with zeros
    const int32 coefficientCount = 4 ;
    
    // prhs[1]: taskHandle
    TaskHandle taskHandle ;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // Determine # of channels
    int32 status ;  // Used several places for DAQmx return codes
    uInt32 channelCount; 
    status = DAQmxGetReadNumChans(taskHandle, &channelCount); 
    handlePossibleDAQmxErrorOrWarning(status);

    // Get the names of the channels
    int32 bufferSizeNeeded = DAQmxGetTaskChannels(taskHandle, NULL, 0) ;  
        // This is the length of the string + 1, for the null terminator
    std::string channelListAsString(bufferSizeNeeded-1, '*');
    status = DAQmxGetTaskChannels(taskHandle, const_cast<char*>(channelListAsString.c_str()), bufferSizeNeeded);
    handlePossibleDAQmxErrorOrWarning(status);

    // Print that string
    //mexPrintf("channelListAsString size: %d\n", bufferSizeNeeded);
    //mexPrintf("channel names: %s\n", channelListAsString.data());

    // channelListAsString now contains a comma-separated list of channel names, e.g.
    // "Dev1/ai0, Dev1/ai1"

    // Parse the list to get a vector of channel names
    std::vector<std::string> channelNames(parseListOfChannelNames(channelListAsString));
    //for (uInt32 i = 0; i < channelCount; ++i) {
    //    mexPrintf("channelNames[%d]: %s\n", i, channelNames[i].c_str());
    //}

    // Allocate the output buffer
    mxArray *outputDataMXArray;
    outputDataMXArray =
        mxCreateNumericMatrix(coefficientCount, channelCount, mxDOUBLE_CLASS, mxREAL);

    // Get a pointer to the storage for the output buffer
    double * outputDataPtr = (double *)mxGetData(outputDataMXArray);

    // Make the DAQmx call, once per channel
    for (uInt32 i = 0; i < channelCount; ++i) {
        status = DAQmxGetAIDevScalingCoeff(taskHandle, channelNames[i].c_str(), outputDataPtr+i*coefficientCount, coefficientCount);
        if (status < 0) {
            mxFree(outputDataMXArray);
        }
        handlePossibleDAQmxErrorOrWarning(status);
        //mexPrintf("coeff[0]: %g\n", *(outputDataPtr + i*coefficientCount + 0));
        //mexPrintf("coeff[1]: %g\n", *(outputDataPtr + i*coefficientCount + 1));
        //mexPrintf("coeff[2]: %g\n", *(outputDataPtr + i*coefficientCount + 2));
        //mexPrintf("coeff[3]: %g\n", *(outputDataPtr + i*coefficientCount + 3));
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
void ReadDigitalU32(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(nrhs, prhs) ;

    // prhs[2]: numSampsPerChanWanted
    int32 numSampsPerChanWanted;  // this does take negative vals in the case of DAQmx_Val_Auto
    if ( (nrhs>2) && mxIsScalar(prhs[2]) )   {
        numSampsPerChanWanted = (int32) mxGetScalar(prhs[2]) ;
    }
    else {
        mexErrMsgTxt("numSampsPerChanWanted must be a scalar");        
    }

    // prhs[3]: timeout
    float64 timeout;
    timeout = readTimeoutArgument(nrhs, prhs, 3) ;
    
    // Determine the number of samples to try to read.
    // If user has requested all the sample available, find out how many that is.
    int32 status;  // Used for DAQmx return code(s)
    int32 numSampsPerChanToTryToRead;
    if (numSampsPerChanWanted>=0)  {
        // The case where the caller gave a number of scans to read
        numSampsPerChanToTryToRead = numSampsPerChanWanted ;
    }
    else {
        // The case where the caller gave DAQmx_Val_Auto for the number of scans to
        // read.
        // In this case, have to find out how many scans are available.
        uInt32 nSampsPerChanAvailable;
        status = DAQmxGetReadAvailSampPerChan(taskHandle,&nSampsPerChanAvailable);
        handlePossibleDAQmxErrorOrWarning(status);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable ;
    }
    
    // Allocate the output buffer
    mxArray *outputDataMXArray;
    outputDataMXArray =
        mxCreateNumericMatrix(numSampsPerChanToTryToRead, 1, mxUINT32_CLASS, mxREAL);

    // Check that the array size is correct
    if ( mxGetNumberOfElements(outputDataMXArray) != (size_t)(numSampsPerChanToTryToRead) )  {
        mexErrMsgTxt("Failed to allocate an output array of the desired size");    
    }

    // Print the buffer size
    mexPrintf("numSampsPerChanToTryToRead: %d\n", numSampsPerChanToTryToRead);

    // Get a pointer to the storage for the output buffer
    uInt32 *outputDataPtr;
    outputDataPtr = (uInt32 *)mxGetData(outputDataMXArray);

    // Read the data
    //mexPrintf("About to try to read %d scans of data\n", numSampsPerChanToTryToRead);
    // The daqmx reading functions complain if you call them when there's no more data to read, 
    // even if you ask for zero scans.
    // So we don't attempt a read if numSampsPerChanToTryToRead is zero.
    int32 numSampsPerChanActuallyRead = 0;
    if (numSampsPerChanToTryToRead>0)  {
        status = DAQmxReadDigitalU32(taskHandle, 
                                     numSampsPerChanToTryToRead, 
                                     timeout, 
                                     DAQmx_Val_GroupByChannel, 
                                     outputDataPtr, 
                                     numSampsPerChanToTryToRead,
                                     &numSampsPerChanActuallyRead, 
                                     NULL);

        // Print the buffer size
        mexPrintf("numSampsPerChanActuallyRead: %d\n", numSampsPerChanActuallyRead);

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
    float64 *writeArray = 0 ;
    mwSize nSampsPerChan ;
    mwSize nChannelsInWriteArray ;
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

    // Check that nSampsPerChan will fit in an int32, and error if not
    if (nSampsPerChan > std::numeric_limits<int32>::max()) {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "writeArray has too many rows, maximum is %d", std::numeric_limits<int32>::max());
    }
    int32 nSampsPerChanAsInt32 = int32(nSampsPerChan);

    // Make the call
    status = DAQmxWriteAnalogF64(taskHandle, 
                                 nSampsPerChanAsInt32,
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
    uInt8 *writeArray = 0 ;
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

    // Check that nSampsPerChan will fit in an int32, and error if not
    if (nSampsPerChan > std::numeric_limits<int32>::max()) {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "writeArray has too many rows, maximum is %d", std::numeric_limits<int32>::max());
    }
    int32 nSampsPerChanAsInt32 = int32(nSampsPerChan);

    //
    // Make the call
    // 
    status = DAQmxWriteDigitalLines(taskHandle, 
                                    nSampsPerChanAsInt32,
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
    char* actionAsCharPtr = mxArrayToString(actionAsMxArray) ;
    std::string action(actionAsCharPtr);
    mxFree(actionAsCharPtr);

    if ( action == "DAQmxCreateTask" )  {
        CreateTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxGetAllTaskHandles" )  {
        GetAllTaskHandles(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxClearTask" )  {
        ClearTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxClearAllTasks" )  {
        ClearAllTasks(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxStartTask" )  {
        StartTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxStopTask" )  {
        StopTask(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxTaskControl" )  {
        TaskControl(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCreateAIVoltageChan" )  {
        CreateAIVoltageChan(nlhs, plhs, nrhs, prhs) ;
    }    
    else if ( action == "DAQmxCreateAOVoltageChan" )  {
        CreateAOVoltageChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCreateDIChan" )  {
        CreateDIChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCreateDOChan" )  {
        CreateDOChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxGetReadAvailSampPerChan" )  {
        GetReadAvailSampPerChan(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxIsTaskDone" )  {
        IsTaskDone(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxReadBinaryI16" )  {
        ReadBinaryI16(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxReadDigitalLines" )  {
        ReadDigitalLines(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxReadDigitalU32" )  {
        ReadDigitalU32(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxWaitUntilTaskDone" )  {
        WaitUntilTaskDone(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxWriteAnalogF64" )  {
        WriteAnalogF64(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxWriteDigitalLines" )  {
        WriteDigitalLines(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCfgSampClkTiming" )  {
        CfgSampClkTiming(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCfgDigEdgeStartTrig" )  {
        CfgDigEdgeStartTrig(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxGetAIDevScalingCoeffs" )  {
        GetAIDevScalingCoeffs(nlhs, plhs, nrhs, prhs) ;
    }
    else  {
        // Doesn't match anything, so error
        mexErrMsgIdAndTxt("ws:ni:noSuchMethod",
                          "DAQmxTaskMaster_() doesn't recognize that method name") ;
    }

    //mexPrintf("About to exit\n");
}
// end of function

