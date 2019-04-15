#include <string>
#include <vector>
#include <limits>
//#include <iostream>
#include <memory>
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
// We use these to check TaskHandles for validity, and thus
// avoid segfaulting.
#define MAXIMUM_TASK_HANDLE_COUNT 32 
TaskHandle TASK_HANDLES[MAXIMUM_TASK_HANDLE_COUNT] ;
int32 TASK_HANDLE_COUNT = 0 ;

bool IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED = false;
mxArray * EVERY_N_SAMPLES_MATLAB_CALLBACK = 0;
uInt32 N_SAMPLES = 0;
TaskHandle EVERY_N_SAMPLES_TASK_HANDLE = (TaskHandle)(0);



#define isfinite(x) ( _finite(x) )        // MSVC-specific, change as needed



int32 CVICALLBACK everyNSamplesCppCallback(TaskHandle taskHandle, int32 everyNsamplesEventType, uInt32 nSamples, void *callbackData) {
    int32 status = 0;
    mxArray *rhs[1];

	//mexPrintf("Inside everyNSamplesCppCallback()\n");
    // Double-check here to make sure something is registered
    if (IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED) {
        rhs[0] = EVERY_N_SAMPLES_MATLAB_CALLBACK;

        mxArray *matlabExceptionOrNull = mexCallMATLABWithTrap(0, NULL, 1, rhs, "feval");
        if (matlabExceptionOrNull) {
            const mxArray * errorStringAsMxArray = mxGetProperty(matlabExceptionOrNull, 0, "message");
            size_t errorStringLength = mxGetN(errorStringAsMxArray);
            size_t bufferLength = errorStringLength + 1;
            std::vector<char> errorStringBuffer(errorStringLength + 1);
            mxGetString(errorStringAsMxArray, errorStringBuffer.data(), bufferLength);
            mexPrintf("Error in everyNSamples callback: %s\n", errorStringBuffer.data());
            status = 1;
        }
    }

    return status;
}



// We want something like sprintf that handles the memory allocation for us, and returns a std::string
// Note that if you want to do something like 
//
//     std::string output = sprintfpp("The string is %s", cstr)
//
// then the cstr has to be a c-style string (not a std::string).  If you have a std::string (call it str), 
// then you need to do
//
//     std::string output = sprintfpp("The string is %s", str.c_str())
//
template<typename ... Args>
std::string
sprintfpp(const std::string & format, Args ... args) {
	size_t size = snprintf(nullptr, 0, format.c_str(), args ...) + 1; // Extra space for '\0'
	std::unique_ptr<char[]> buffer(new char[size]);
	snprintf(buffer.get(), size, format.c_str(), args ...);
	return std::string(buffer.get(), buffer.get() + size - 1); // We don't want the '\0' inside
}



template<typename ... Args>
void
printfpp(const std::string & format, Args ... args) {
	std::string stringToPrint = sprintfpp(format, args ...);
	mexPrintf(stringToPrint.c_str());
}



void
handlePossibleDAQmxErrorOrWarning(int32 errorCode, std::string action)  {
    // Ignore no-error condition, and also (controversially) ignore warnings
    if (errorCode >= 0)
        return;
    int32 rawErrorMessageBufferSize = DAQmxGetErrorString(errorCode,NULL,0);  // Probe to get the required buffer size
    std::vector<char> rawErrorMessageBuffer(rawErrorMessageBufferSize);  // this is right, no +1 needed for string terminator
    DAQmxGetErrorString(errorCode, rawErrorMessageBuffer.data(), rawErrorMessageBufferSize);
    std::string rawErrorMessage(rawErrorMessageBuffer.data());
    int32 errorMessageBufferSize = rawErrorMessageBufferSize+100 ;
    // Can't have "-" in errorID, so work around this...
    int32 errorCodeMagnitude = -errorCode;
    std::string errorID = sprintfpp("ws:ni:DAQmxError:%s%d",
                                    "n",
                                    errorCodeMagnitude); 
    std::string errorMessage = 
        sprintfpp("DAQmx Error (%d) in %s: %s", 
                  errorCode, 
                  action.c_str(), 
                  rawErrorMessage.c_str());
    //mexPrintf("here!\n");
    //mexPrintf("id: %s, msg: %s\n",errorID,errorMessage);
    mexErrMsgIdAndTxt(errorID.c_str(), errorMessage.c_str());
}
// end of function



/*
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
            mexErrMsgIdAndTxt("ws:ni:BadArgument","%s cannot be missing",argumentName.c_str());
        }
    }
    else  {
        // Arg exists
        if ( mxIsEmpty(prhs[index]) )  {
            if (isEmptyAllowed)  {
                result = std::make_pair(true, "");
            }
            else {
                mexErrMsgIdAndTxt("ws:ni:BadArgument","%s cannot be empty",argumentName.c_str());
            }
        }
        else {
            // Arg exists, is nonempty
            if ( !mxIsChar(prhs[index]) )  {
                mexErrMsgIdAndTxt("ws:ni:BadArgument","%s must be a string",argumentName.c_str());
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
*/


std::string
readMandatoryStringArgument(int nrhs, const mxArray *prhs[],
                            int index, const std::string & argumentName,
                            int isEmptyAllowed) {
    std::string result;

    if (nrhs<index + 1) {
        // Arg is missing
        mexErrMsgIdAndTxt("ws:ni:BadArgument", "%s cannot be missing", argumentName.c_str());
    }
    else {
        // Arg exists
        if (mxIsEmpty(prhs[index])) {
            if (isEmptyAllowed) {
                result = "" ;
            }
            else {
                mexErrMsgIdAndTxt("ws:ni:BadArgument", "%s cannot be empty", argumentName.c_str());
            }
        }
        else {
            // Arg exists, is nonempty
            if (!mxIsChar(prhs[index])) {
                mexErrMsgIdAndTxt("ws:ni:BadArgument", "%s must be a string", argumentName.c_str());
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
    else if (valueAsString == "DAQmx_Val_FiniteSamps") {
        resultMaybe = std::make_pair(true, DAQmx_Val_FiniteSamps);
    }
    else if ( valueAsString == "DAQmx_Val_Falling" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Falling) ;
    }
    else if ( valueAsString == "DAQmx_Val_Rising" )  {
        resultMaybe = std::make_pair(true, DAQmx_Val_Rising) ;
    }
    else if (valueAsString == "DAQmx_Val_Low") {
        resultMaybe = std::make_pair(true, DAQmx_Val_Low);
    }
    else if (valueAsString == "DAQmx_Val_High") {
        resultMaybe = std::make_pair(true, DAQmx_Val_High);
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
    else if (valueAsString == "DAQmx_Val_Cfg_Default") {
        resultMaybe = std::make_pair(true, DAQmx_Val_Cfg_Default);
    }
    else if (valueAsString == "DAQmx_Val_Diff") {
        resultMaybe = std::make_pair(true, DAQmx_Val_Diff);
    }
    else if (valueAsString == "DAQmx_Val_RSE") {
        resultMaybe = std::make_pair(true, DAQmx_Val_RSE);
    }
    else if (valueAsString == "DAQmx_Val_NRSE") {
        resultMaybe = std::make_pair(true, DAQmx_Val_NRSE);
    }   
    else if (valueAsString == "DAQmx_Val_PseudoDiff") {
        resultMaybe = std::make_pair(true, DAQmx_Val_PseudoDiff);
    }
    else if (valueAsString == "DAQmx_Val_CounterOutputEvent") {
        resultMaybe = std::make_pair(true, DAQmx_Val_CounterOutputEvent);
    }
    else  {
        // Doesn't match anything, so result is empty
        resultMaybe = std::make_pair(false, 0);
    }
    return resultMaybe ;
}


std::string 
busTypeStringFromCode(int32 busTypeCode) {
    std::string result;
    switch (busTypeCode) {
    case DAQmx_Val_PCI:
        result = "DAQmx_Val_PCI";
        break;
    case DAQmx_Val_PCIe:
        result = "DAQmx_Val_PCIe";
        break;
    case DAQmx_Val_PXI:
        result = "DAQmx_Val_PXI";
        break;
    case DAQmx_Val_PXIe:
        result = "DAQmx_Val_PXIe";
        break;
    case DAQmx_Val_SCXI:
        result = "DAQmx_Val_SCXI";
        break;
    case DAQmx_Val_SCC:
        result = "DAQmx_Val_SCC";
        break;
    case DAQmx_Val_PCCard:
        result = "DAQmx_Val_PCCard";
        break;
    case DAQmx_Val_USB:
        result = "DAQmx_Val_USB";
        break;
    case DAQmx_Val_CompactDAQ:
        result = "DAQmx_Val_CompactDAQ";
        break;
    case DAQmx_Val_CompactRIO:
        result = "DAQmx_Val_CompactRIO";
        break;
    case DAQmx_Val_TCPIP:
        result = "DAQmx_Val_TCPIP";
        break;
    case DAQmx_Val_Unknown:
        result = "DAQmx_Val_Unknown";
        break;
    case DAQmx_Val_SwitchBlock:
        result = "DAQmx_Val_SwitchBlock";
        break;
    default:
        result = "Unknown bus type code: " + std::to_string((int)busTypeCode);
    }
    return result;
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
        std::string errorMessage = sprintfpp("Did not recognize value %s for argument %s", valueAsString.c_str(), argumentName.c_str());
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          errorMessage.c_str());
    }

    int32 result = resultMaybe.second ;
    return result ;
}

    

// Helper function for reading a task handle argument and validating it
TaskHandle
readTaskHandleArgument(std::string action, int nrhs, const mxArray *prhs[])  {
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
            std::string errorMessage = sprintfpp("In ws.ni 'method' %s, taskHandle is not a registered task handle", action.c_str());
            mexErrMsgIdAndTxt("ws:ni:badArgument",
                              errorMessage.c_str());
        }
        // If get here, taskHandle is a registered task handle
    }
    else  {
        std::string errorMessage = sprintfpp("In ws.ni 'method' %s, taskHandle must be a uint64 scalar", action.c_str());
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          errorMessage.c_str());
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


    
// A helper function that calls DAQmxRegisterEveryNSamplesEvent() to unregister the 
// callback and modifies the globals appropriately.
// Never throws a Matlab error, returns the status from DAQmxRegisterEveryNSamplesEvent(),
// or zero if no callback is registered.
int32 unregisterEveryNSamplesEventAndUpdateGlobals(bool doIgnoreErrors) {
    int32 status = 0;
    if (IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED) {
        // Call the DAQmx function
        status =
            DAQmxRegisterEveryNSamplesEvent(
                EVERY_N_SAMPLES_TASK_HANDLE,
                DAQmx_Val_Acquired_Into_Buffer,
                N_SAMPLES,
                DAQmx_Val_SynchronousEventCallbacks,
                (DAQmxEveryNSamplesEventCallbackPtr)(0),
                (void *)(0));
		//mexPrintf("Return from call to DAQmxRegisterEveryNSamplesEvent() to unregister was %d\n", status);
        status = doIgnoreErrors ? 0 : status;

        // If that worked, update the global variables
        if (status >= 0) {
			//mexPrintf("About to set IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED = false\n");
            IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED = false;
            mxDestroyArray(EVERY_N_SAMPLES_MATLAB_CALLBACK);
            EVERY_N_SAMPLES_MATLAB_CALLBACK = (mxArray *)(0);
            EVERY_N_SAMPLES_TASK_HANDLE = (TaskHandle)(0);
            N_SAMPLES = 0;
        }
    }

    return status;
}
// end of function



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
clearTaskByIndex(int32 taskHandleIndex, bool doIgnoreErrors)  {
    int32 status ;

    //mexPrintf("Just entered clearTaskByIndex, with taskHandleIndex = %d\n", taskHandleIndex) ;
    if ( 0 <= taskHandleIndex && taskHandleIndex < TASK_HANDLE_COUNT )  {
        TaskHandle taskHandle = TASK_HANDLES[taskHandleIndex] ;
        if (IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED && taskHandle == EVERY_N_SAMPLES_TASK_HANDLE) {
            status = unregisterEveryNSamplesEventAndUpdateGlobals(doIgnoreErrors);
            status = doIgnoreErrors ? 0 : status;
            if (status < 0) {
                return status;
            }
        }
        status = DAQmxClearTask(taskHandle);
        status = doIgnoreErrors ? 0 : status;
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
clearAllTasks(bool doIgnoreErrors)  {
    int32 status = 0 ;  // Used several places for DAQmx return codes
    int32 taskHandleIndex ;

    // Delete each task, last to first
    //for ( taskHandleIndex=0 ; taskHandleIndex<TASK_HANDLE_COUNT ; ++taskHandleIndex)  {
    for (taskHandleIndex=(TASK_HANDLE_COUNT-1); taskHandleIndex>=0; --taskHandleIndex)  {  // faster
        int32 thisStatus = clearTaskByIndex(taskHandleIndex, doIgnoreErrors) ;
        if ( thisStatus < 0 )  {  // ignore warnings but not errors
            status = thisStatus ;
        }
    }
    
    return status ;
}
// end of function



// This will be registered with mexAtExit()
static void finalize(void)  {
    // If a callback is registered, unregister it
    const bool doIgnoreErrors = true;
    unregisterEveryNSamplesEventAndUpdateGlobals(doIgnoreErrors);

    // Clear all the tasks
    clearAllTasks(doIgnoreErrors) ;  // Ignore return value, b/c can't do anything about it anyway
    
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
CreateTask(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
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
    std::string taskName(readMandatoryStringArgument(nrhs, prhs, 1, "taskName", EMPTY_IS_NOT_ALLOWED)) ;

    //mexPrintf("Point 2\n");

    // Create the task
    status = DAQmxCreateTask(taskName.c_str(), &taskHandle) ;
    handlePossibleDAQmxErrorOrWarning(status, action); 

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
void GetAllTaskHandles(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
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
void ClearTask(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;
        // This will error out if there are zero registered tasks
    
    // Find the index of the task handle
    int taskHandleIndex = findTaskByHandle(taskHandle) ;
    if ( taskHandleIndex < 0 )  {
        mexErrMsgIdAndTxt("ws:ni:BadArgument", "Not a valid task handle");
    }
    
    // Clear the task
    const bool doIgnoreErrors = false;
    int32 status;  // Used several places for DAQmx return codes
    status = clearTaskByIndex(taskHandleIndex, doIgnoreErrors) ;
    handlePossibleDAQmxErrorOrWarning(status, action);
    
    // If get here, task was successfully un-registered                    
}



// DAQmxClearAllTasks()
void ClearAllTasks(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    const bool doIgnoreErrors = false;
    int32 status = clearAllTasks(doIgnoreErrors) ;
    handlePossibleDAQmxErrorOrWarning(status, action);
}



// DAQmxStartTask(taskHandle)
void StartTask(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxStartTask(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxStopTask(taskHandle)
void StopTask(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;

    //
    // Read input arguments
    //

    // prhs[0]: taskHandle
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxStopTask(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxTaskControl(taskHandle, taskAction)
void TaskControl(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    int32 taskAction ;

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: taskAction
    taskAction = readValueArgument(nrhs, prhs, 
                                   2, "taskAction") ;

    // Make the call
    status = DAQmxTaskControl(taskHandle, taskAction) ;
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxCfgDigEdgeStartTrig(taskHandle, triggerSource, triggerEdge)
void CfgDigEdgeStartTrig(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: triggerSource
    int index=2 ;
    std::string triggerSource( readMandatoryStringArgument(nrhs, prhs,
                                                           index, "triggerSource",
                                                           EMPTY_IS_NOT_ALLOWED) );

    // prhs[3]: triggerEdge
    index++ ;
    int32 triggerEdge;
    triggerEdge = readValueArgument(nrhs, prhs,
                                    index, "triggerEdge") ;

    // Make the call
    int32 status ;
    status = DAQmxCfgDigEdgeStartTrig(taskHandle, triggerSource.c_str(), triggerEdge) ;
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxDisableStartTrig(taskHandle)
void DisableStartTrig(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // Make the call
    int32 status = DAQmxDisableStartTrig(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxCfgSampClkTiming(taskHandle,source,rate,activeEdge,sampleMode,sampsPerChanToAcquire)
void CfgSampClkTiming(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // prhs[1]: taskHandle
    // prhs[2]: source
    // prhs[3]: rate
    // prhs[4]: activeEdge
    // prhs[5]: sampleMode
    // prhs[6]: sampsPerChanToAcquire

    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: source
    std::string source( readMandatoryStringArgument(nrhs, prhs, 2, "source", EMPTY_IS_ALLOWED) ) ;

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
    const char * sourceArgument = (source.empty() ? NULL : source.c_str()) ;
    status = DAQmxCfgSampClkTiming(taskHandle,
                                   sourceArgument,
                                   rate, 
                                   activeEdge, 
                                   sampleMode,
                                   sampsPerChanToAcquire);
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxCreateAIVoltageChan(taskHandle, physicalChannelName, terminalConfig)
void CreateAIVoltageChan(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: physicalChannelName
    std::string physicalChannelName =
        readMandatoryStringArgument(nrhs, prhs,
                                    2, "physicalChannelName",
                                    EMPTY_IS_NOT_ALLOWED);

    // prhs[3]: termination
    int32 terminalConfig =
        readValueArgument(nrhs, prhs, 3, "terminalConfig");

    //
    // Make the call
    //
    int32 status = 
        DAQmxCreateAIVoltageChan(taskHandle,
                                 physicalChannelName.c_str(),
                                 NULL,
                                 terminalConfig,
                                 -10.0, 
                                 +10.0, 
                                 DAQmx_Val_Volts, 
                                 NULL);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxCreateAOVoltageChan(taskHandle, physicalChannelName)
void CreateAOVoltageChan(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    // prhs[1]: taskHandle
    // prhs[2]: physicalChannelName

    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

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
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxCreateDIChan(taskHandle, lines, lineGrouping)
void CreateDIChan(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: lines
    std::string lines( readMandatoryStringArgument(nrhs, prhs, 2, "lines", 
                                                   EMPTY_IS_NOT_ALLOWED) ) ;

    // prhs[3]: lineGrouping
    int32 lineGrouping = readValueArgument(nrhs, prhs, 3, "lineGrouping");

    // Make the call
    int32 status;
    status = DAQmxCreateDIChan(taskHandle,
                               lines.c_str(), 
                               NULL, 
                               lineGrouping) ;
    // Setting the fourth argument to DAQmx_Val_ChanPerLine guarantees (I think) that
    // if you call DAQmxReadDigitalLines() later, it will always
    // return 1 for numBytesPerSamp.  This is nice b/c it means we
    // don't have to return that if/when we wrap DAQmxReadDigitalLines().
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// DAQmxCreateDOChan(taskHandle, lines)
void CreateDOChan(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: physicalLineName
    std::string lines(readMandatoryStringArgument(nrhs, prhs, 2, "lines",
                                                  EMPTY_IS_NOT_ALLOWED));

    // prhs[3]: lineGrouping
    int32 lineGrouping = readValueArgument(nrhs, prhs, 3, "lineGrouping");

    // Make the call
    status = DAQmxCreateDOChan(taskHandle, 
                               lines.c_str(), 
                               NULL, 
                               lineGrouping) ;
    handlePossibleDAQmxErrorOrWarning(status, action);
    }
// end of function



// nSampsPerChanAvail = DAQmxGetReadAvailSampPerChan(taskHandle)
void GetReadAvailSampPerChan(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    uInt32 nSampsPerChanAvail ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    //
    // Make the call
    //
    status = DAQmxGetReadAvailSampPerChan(taskHandle, &nSampsPerChanAvail);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Return output data
    plhs[0] = mxCreateDoubleScalar((double)nSampsPerChanAvail) ;  
    }
// end of function



// isTaskDone = DAQmxIsTaskDone(taskHandle)
void IsTaskDone(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
    {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // Make the call
    int32 status;
    bool32 isTaskDone;
    status = DAQmxIsTaskDone(taskHandle, &isTaskDone);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Return output data
    plhs[0] = mxCreateLogicalScalar(isTaskDone?true:false) ;  // Using tenary op prevents warning
    }
// end of function



// outputData = DAQmxReadBinaryI16(taskHandle, nSampsPerChanWanted, timeout)
void ReadBinaryI16(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
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
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

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
    handlePossibleDAQmxErrorOrWarning(status, action);
    
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
        handlePossibleDAQmxErrorOrWarning(status, action);
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
        handlePossibleDAQmxErrorOrWarning(status, action);
        }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// outputData = DAQmxReadAnalogF64(taskHandle, nSampsPerChanWanted, timeout)
void ReadAnalogF64(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    // prhs[2]: numSampsPerChanRequested
    // prhs[3]: timeout

    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: numSampsPerChanRequested
    int32 numSampsPerChanRequested;  // this does take negative vals in the case of DAQmx_Val_Auto
    if ((nrhs>2) && mxIsScalar(prhs[2]))  {
        numSampsPerChanRequested = (int32)mxGetScalar(prhs[2]);
    }
    else  {
        mexErrMsgTxt("numSampsPerChanRequested must be a scalar");
    }

    // prhs[3]: timeout
    float64 timeout = readTimeoutArgument(nrhs, prhs, 3);

    // Determine # of channels
    uInt32 numChannels;
    int32 status = DAQmxGetReadNumChans(taskHandle, &numChannels);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Determine the number of samples to try to read.
    // If user has requested all the sample available, find out how many that is.
    int32 numSampsPerChanToTryToRead;
    if (numSampsPerChanRequested >= 0)  {
        numSampsPerChanToTryToRead = numSampsPerChanRequested;
    }
    else {
        // In this case, have to find out how many scans are available
        uInt32 nSampsPerChanAvailable;
        status = DAQmxGetReadAvailSampPerChan(taskHandle, &nSampsPerChanAvailable);
        handlePossibleDAQmxErrorOrWarning(status, action);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable;
    }

    // Allocate the output buffer
    mxArray *outputDataMXArray;
    outputDataMXArray =
        mxCreateNumericMatrix(numSampsPerChanToTryToRead, numChannels, mxDOUBLE_CLASS, mxREAL);

    // Check that the array size is correct
    uInt32 arraySizeInSamps = ((uInt32)numSampsPerChanToTryToRead) * numChannels;
    if (mxGetNumberOfElements(outputDataMXArray) != (size_t)(arraySizeInSamps))  {
        mexErrMsgTxt("Failed to allocate an output array of the desired size");
    }

    // Get a pointer to the storage for the output buffer
    float64 *outputDataPtr;
    outputDataPtr = (float64 *)mxGetData(outputDataMXArray);

    // Read the data
    //mexPrintf("About to try to read %d scans of data\n", numSampsPerChanToTryToRead);
    // The daqmx reading functions complain if you call them when there's no more data to read, 
    // even if you ask for zero scans.
    // So we don't attempt a read if numSampsPerChanToTryToRead is zero.
    if (numSampsPerChanToTryToRead>0)  {
        int32 numSampsPerChanRead;
        status = DAQmxReadAnalogF64(
            taskHandle,
            numSampsPerChanToTryToRead,
            timeout,
            DAQmx_Val_GroupByChannel,
            outputDataPtr,
            arraySizeInSamps,
            &numSampsPerChanRead,
            NULL);

        // Check for error during the read
        handlePossibleDAQmxErrorOrWarning(status, action);
    }

    // Return output data
    plhs[0] = outputDataMXArray;
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
void GetAIDevScalingCoeffs(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // All X series devices seem to return 4 coefficients
    // Simulated X series return 2, but we just fill in the rest with zeros
    const int32 coefficientCount = 4 ;
    
    // prhs[1]: taskHandle
    TaskHandle taskHandle ;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // Determine # of channels
    int32 status ;  // Used several places for DAQmx return codes
    uInt32 channelCount; 
    status = DAQmxGetReadNumChans(taskHandle, &channelCount); 
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Get the names of the channels
    int32 bufferSize = DAQmxGetTaskChannels(taskHandle, NULL, 0) ;  // This is the length of the string + 1, for the null terminator
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem
    std::vector<char> channelListAsCharVector(bufferSize);
    //status = DAQmxGetTaskChannels(taskHandle, const_cast<char*>(channelListAsCharVector.data()), bufferSizeNeeded);
    status = DAQmxGetTaskChannels(taskHandle, channelListAsCharVector.data(), bufferSize);
    handlePossibleDAQmxErrorOrWarning(status, action);
    std::string channelListAsString(channelListAsCharVector.data());

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
        handlePossibleDAQmxErrorOrWarning(status, action);
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
void ReadDigitalLines(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
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
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

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
        handlePossibleDAQmxErrorOrWarning(status, action);
        numSampsPerChanToTryToRead = nSampsPerChanAvailable ;
        }
    
    // Determine # of channels
    status = DAQmxGetReadNumChans(taskHandle,&numChannels); 
    handlePossibleDAQmxErrorOrWarning(status, action);
    
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
        handlePossibleDAQmxErrorOrWarning(status, action);

        // If things are as we expect, numBytesPerSamp should *always* be one
        // Another way of saying this is that we don't support configurations of the DI lines 
        // such that numBytesPerSamp is greater than 1
        if ( numBytesPerSamp != 1)
            {
            mexErrMsgIdAndTxt("ws:ni:numBytesPerSampIsWrong",
                              "numBytesPerSamp is %d, it should be one", numBytesPerSamp);        
            }
        }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// outputData = DAQmxReadDigitalU32(taskHandle, nSampsPerChanWanted, timeout)
void ReadDigitalU32(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle;
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

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
        handlePossibleDAQmxErrorOrWarning(status, action);
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
    //mexPrintf("numSampsPerChanToTryToRead: %d\n", numSampsPerChanToTryToRead);

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
        //mexPrintf("numSampsPerChanActuallyRead: %d\n", numSampsPerChanActuallyRead);

        // Check for error during the read
        handlePossibleDAQmxErrorOrWarning(status, action);
    }

    // Return output data
    plhs[0] = outputDataMXArray ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// DAQmxWaitUntilTaskDone(taskHandle, timeToWait)
void WaitUntilTaskDone(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 status ;  // Used several places for DAQmx return codes
    TaskHandle taskHandle ;
    float64 timeToWait ;
    int index ;

    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

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
    handlePossibleDAQmxErrorOrWarning(status, action);
}



// sampsPerChanWritten = DAQmxWriteAnalogF64(taskHandle, autoStart, timeout, writeArray)
void WriteAnalogF64(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  
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
    taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

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
    handlePossibleDAQmxErrorOrWarning(status, action);

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
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Return output data
    plhs[0] = mxCreateDoubleScalar(nSampsPerChanWritten) ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
    }



// sampsPerChanWritten = DAQmxWriteDigitalLines(taskHandle, autoStart, timeout, writeArray)
void WriteDigitalLines(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs) ;

    // prhs[2]: autoStart
    bool32 autoStart;
    int index = 2; // index of the input arg we're currently dealing with
    if ( (nrhs>index) && mxIsScalar(prhs[index]) )  {
        autoStart = (bool32) mxGetScalar(prhs[index]) ;
    }
    else  {
        mexErrMsgTxt("autoStart must be a scalar");        
    }

    // prhs[3]: timeout
    index++;
    float64 timeout = readTimeoutArgument(nrhs, prhs, index) ;

    // prhs[4]: writeArray
    uInt8 *writeArray = 0;
    size_t nSampsPerChan;
    size_t nChannelsInWriteArray;
    index++;
    if ( nrhs>index && mxIsLogical(prhs[index]) && mxGetNumberOfDimensions(prhs[index])==2 )  {
        nSampsPerChan = mxGetM(prhs[index]) ;
        nChannelsInWriteArray = mxGetN(prhs[index]) ;
        writeArray = (uInt8 *)mxGetData(prhs[index]) ;
    }
    else  {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "writeArray must be a matrix of class logical");        
    }

    // Determine # of channels in task
    uInt32 nChannelsInTask;
    int32 status = DAQmxGetWriteNumChans(taskHandle,&nChannelsInTask);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Verify the number of channels in the task equals that in the writeArray
    //mexPrintf("nChannelsInTask: %d\n",nChannelsInTask) ;
    //mexPrintf("nChannelsInWriteArray: %d\n",nChannelsInWriteArray) ;    
    if (nChannelsInTask != nChannelsInWriteArray)  {
        mexErrMsgIdAndTxt("ws:ni:badArgument",
                          "writeArray must have the same number of columns as the task has channels");
    }

    // Check that nSampsPerChan will fit in an int32, and error if not
    if (nSampsPerChan > std::numeric_limits<int32>::max())  {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "writeArray has too many rows, maximum is %d", std::numeric_limits<int32>::max());
    }
    int32 nSampsPerChanAsInt32 = int32(nSampsPerChan);

    //
    // Make the call
    // 
    int32 nSampsPerChanWritten;
    status = DAQmxWriteDigitalLines(taskHandle,
                                    nSampsPerChanAsInt32,
                                    autoStart,
                                    timeout, 
                                    DAQmx_Val_GroupByChannel,
                                    writeArray,
                                    &nSampsPerChanWritten, 
                                    NULL);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Return output data
    plhs[0] = mxCreateDoubleScalar(nSampsPerChanWritten) ;  
        // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned        
}
// end of function



// deviceNames = DAQmxGetSysDevNames()
void GetSysDevNames(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    int32 bufferSize = DAQmxGetSysDevNames(NULL, 0) ;
        // Probe to get the required buffer size
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem
    //mexPrintf("Queried buffer size is: %d\n", (int)(bufferSize));
    std::vector<char> resultAsCharVector(bufferSize);
    int32 status = DAQmxGetSysDevNames(resultAsCharVector.data(), (uInt32)(bufferSize)) ;
    handlePossibleDAQmxErrorOrWarning(status, action);
    // Return output data
    plhs[0] = mxCreateString(resultAsCharVector.data());
}
// end of function



// diLinesAsString = DAQmxGetDevDILines(deviceName)
void GetDevDILines(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // prhs[1]: deviceName
    std::string deviceName(
        readMandatoryStringArgument(nrhs, prhs,
                                    1, "deviceName",
                                    EMPTY_IS_NOT_ALLOWED));

    // Make the calls
    int32 bufferSize = DAQmxGetDevDILines(deviceName.c_str(), NULL, 0);
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem
    // Probe to get the required buffer size
    //mexPrintf("Queried buffer size is: %d\n", (int)(bufferSize));
    std::vector<char> resultAsCharVector(bufferSize);
    int32 status = DAQmxGetDevDILines(deviceName.c_str(), resultAsCharVector.data(), (uInt32)(bufferSize));
    handlePossibleDAQmxErrorOrWarning(status, action);
    // Return output data
    //if (!resultAsCharVector.data()) {
    //    mexPrintf("resultAsCharVector.data() is null\n");
    //}
    plhs[0] = mxCreateString(resultAsCharVector.data());
}
// end of function



// coPhysicalChannelsAsString = DAQmxGetDevCOPhysicalChans(deviceName)
void GetDevCOPhysicalChans(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // prhs[1]: deviceName
    std::string deviceName(
        readMandatoryStringArgument(nrhs, prhs,
            1, "deviceName",
            EMPTY_IS_NOT_ALLOWED));

    // Make the calls
    int32 bufferSize = DAQmxGetDevCOPhysicalChans(deviceName.c_str(), NULL, 0);  // Probe to get the required buffer size
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem                                                    
    //mexPrintf("Queried buffer size is: %d\n", (int)(bufferSize));
    std::vector<char> resultAsCharVector(bufferSize);
    int32 status = DAQmxGetDevCOPhysicalChans(deviceName.c_str(), resultAsCharVector.data(), (uInt32)(bufferSize));
    handlePossibleDAQmxErrorOrWarning(status, action);
    // Return output data
    plhs[0] = mxCreateString(resultAsCharVector.data());
}
// end of function



// channelsAsString = DAQmxGetDevAIPhysicalChans(deviceName)
void GetDevAIPhysicalChans(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // prhs[1]: deviceName
    std::string deviceName(
        readMandatoryStringArgument(nrhs, prhs,
            1, "deviceName",
            EMPTY_IS_NOT_ALLOWED));

    // Make the calls
    int32 bufferSize = DAQmxGetDevAIPhysicalChans(deviceName.c_str(), NULL, 0);  // Probe to get the required buffer size
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem
    //mexPrintf("Queried buffer size is: %d\n", (int)(bufferSize));
    std::vector<char> resultAsCharVector(bufferSize);
    int32 status = DAQmxGetDevAIPhysicalChans(deviceName.c_str(), resultAsCharVector.data(), (uInt32)(bufferSize));
    handlePossibleDAQmxErrorOrWarning(status, action);
    // Return output data
    plhs[0] = mxCreateString(resultAsCharVector.data());
}
// end of function


// channelsAsString = DAQmxGetDevAOPhysicalChans(deviceName)
void GetDevAOPhysicalChans(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    // prhs[1]: deviceName
    std::string deviceName(
        readMandatoryStringArgument(nrhs, prhs,
            1, "deviceName",
            EMPTY_IS_NOT_ALLOWED));

    // Make the calls
    int32 bufferSize = DAQmxGetDevAOPhysicalChans(deviceName.c_str(), NULL, 0);
    // Probe to get the required buffer size
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem
    //mexPrintf("Queried buffer size is: %d\n", (int)(bufferSize));
    std::vector<char> resultAsCharVector(bufferSize);
    int32 status = DAQmxGetDevAOPhysicalChans(deviceName.c_str(), resultAsCharVector.data(), (uInt32)(bufferSize));
    handlePossibleDAQmxErrorOrWarning(status, action);
    // Return output data
    plhs[0] = mxCreateString(resultAsCharVector.data());
}
// end of function



// busTypeAsString = DAQmxGetDevBusType(deviceName)
void GetDevBusType(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: deviceName
    std::string deviceName(
        readMandatoryStringArgument(nrhs, prhs,
            1, "deviceName",
            EMPTY_IS_NOT_ALLOWED));

    // Make the calls
    int32 busTypeCode;
    int32 status = DAQmxGetDevBusType(deviceName.c_str(), &busTypeCode);
    handlePossibleDAQmxErrorOrWarning(status, action);
    std::string busTypeAsString = busTypeStringFromCode(busTypeCode);
    // Return output data
    plhs[0] = mxCreateString(busTypeAsString.c_str());
}
// end of function



// terminalName = DAQmxGetRefClkSrc(taskHandle)
void GetRefClkSrc(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // Make the calls
    int32 bufferSize = DAQmxGetRefClkSrc(taskHandle, NULL, 0);  // Probe to get the required buffer size
    handlePossibleDAQmxErrorOrWarning(bufferSize, action);  // This is an error code if there was a problem
    //mexPrintf("Queried buffer size is: %d\n", (int)(bufferSize));
    std::vector<char> resultAsCharVector(bufferSize);
    int32 status = DAQmxGetRefClkSrc(taskHandle, resultAsCharVector.data(), (uInt32)(bufferSize));
    handlePossibleDAQmxErrorOrWarning(status, action);
    // Return output data
    plhs[0] = mxCreateString(resultAsCharVector.data());
}
// end of function



// DAQmxSetRefClkSrc(taskHandle, terminalName)
void SetRefClkSrc(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    //
    // Read input arguments
    //

    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: terminalName
    std::string terminalName(
        readMandatoryStringArgument(nrhs, prhs,
            2, "terminalName",
            EMPTY_IS_NOT_ALLOWED));

    //
    // Make the call
    // 
    int32 status = DAQmxSetRefClkSrc(taskHandle, terminalName.c_str());
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// rate = DAQmxGetRefClkRate(taskHandle)
void GetRefClkRate(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // Make the call
    float64 result;
    int32 status = DAQmxGetRefClkRate(taskHandle, &result);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Return output data
    plhs[0] = mxCreateDoubleScalar(result);
}
// end of function



// DAQmxSetRefClkRate(taskHandle, rate)
void SetRefClkRate(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: rate
    int index = 2;
    float64 rate;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        rate = mxGetScalar(prhs[index]);
        //mexPrintf("rate is %g\n", rate);
        if ((rate <= 0) || !isfinite(rate)) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "rate must be a finite, positive value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "rate must be a numeric non-complex scalar");
    }

    // Make the call
    int32 status = DAQmxSetRefClkRate(taskHandle, rate);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// rate = DAQmxGetSampClkRate(taskHandle)
void GetSampClkRate(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	// prhs[1]: taskHandle
	TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

	// Make the call
	float64 result;
	int32 status = DAQmxGetSampClkRate(taskHandle, &result);
	handlePossibleDAQmxErrorOrWarning(status, action);

	// Return output data
	plhs[0] = mxCreateDoubleScalar(result);
}
// end of function



// sz = DAQmxGetBufOutputBufSize(taskHandle)
void GetBufOutputBufSize(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // Make the call
    uInt32 result;
    int32 status = DAQmxGetBufOutputBufSize(taskHandle, &result);
    handlePossibleDAQmxErrorOrWarning(status, action);

    // Return output data
    plhs[0] = mxCreateDoubleScalar((float64)result);
}
// end of function



// DAQmxCfgOutputBuffer(taskHandle, scanCount)
void CfgOutputBuffer(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: scanCount
    int index = 2;
    double scanCountAsDouble;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index]))  {
        scanCountAsDouble = mxGetScalar(prhs[index]);
        //mexPrintf("rate is %g\n", rate);
        if (!isfinite(scanCountAsDouble) || scanCountAsDouble < 0 || scanCountAsDouble>4294967295.0)  {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "scanCount must be a finite, positive value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "scanCount must be a numeric non-complex scalar");
    }
    uInt32 scanCount = uInt32(round(scanCountAsDouble));

    // Make the call
    int32 status = DAQmxCfgOutputBuffer(taskHandle, scanCount);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxResetWriteRelativeTo(taskHandle)
void ResetWriteRelativeTo(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // Make the call
    int32 status = DAQmxResetWriteRelativeTo(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxResetWriteOffset(taskHandle)
void ResetWriteOffset(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // Make the call
    int32 status = DAQmxResetWriteOffset(taskHandle);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxCreateCOPulseChanFreq(taskHandle, counter, idleState, initialDelay, freq, dutyCycle)
void CreateCOPulseChanFreq(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: counter
    std::string counter =
        readMandatoryStringArgument(nrhs, prhs,
                                    2, "counter",
                                    EMPTY_IS_NOT_ALLOWED);

    // prhs[3]: idleState
    int32 idleState =
        readValueArgument(nrhs, prhs, 3, "idleState");

    // prhs[4]: initialDelay
    int index = 4;
    float64 initialDelay;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        initialDelay = mxGetScalar(prhs[index]);
        if (!isfinite(initialDelay) || initialDelay<0.0) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "initialDelay must be a finite, nonnegative value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "initialDelay must be a numeric non-complex scalar");
    }

    // prhs[5]: freq
    ++index;
    float64 freq;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        freq = mxGetScalar(prhs[index]);
        if (!isfinite(freq) || freq<=0.0) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "freq must be a finite, positive value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "freq must be a numeric non-complex scalar");
    }

    // prhs[6]: dutyCycle
    ++index;
    float64 dutyCycle;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        dutyCycle = mxGetScalar(prhs[index]);
        if (!isfinite(dutyCycle) || dutyCycle <= 0.0 || dutyCycle >= 1.0) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "dutyCycle must be a finite value greater than 0.0 and less than 1.0");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "dutyCycle must be a numeric non-complex scalar");
    }


    //
    // Make the call
    //
    int32 status =
        DAQmxCreateCOPulseChanFreq(taskHandle, 
                                   counter.c_str(), 
                                   NULL, 
                                   DAQmx_Val_Hz, 
                                   idleState, 
                                   initialDelay, 
                                   freq, 
                                   dutyCycle);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxCfgImplicitTiming(taskHandle, sampleMode, sampsPerChanToAcquire)
void CfgImplicitTiming(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: sampleMode
    int32 sampleMode =
        readValueArgument(nrhs, prhs, 2, "sampleMode");

    // prhs[3]: sampsPerChanToAcquire
    int index = 3;
    double sampsPerChanToAcquireAsDouble;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        sampsPerChanToAcquireAsDouble = mxGetScalar(prhs[index]);
        //mexPrintf("rate is %g\n", rate);
        if (!isfinite(sampsPerChanToAcquireAsDouble) || sampsPerChanToAcquireAsDouble < 0 || sampsPerChanToAcquireAsDouble > std::numeric_limits<uInt64>::max()) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "sampsPerChanToAcquire must be a finite, positive value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "sampsPerChanToAcquire must be a numeric non-complex scalar");
    }
    uInt64 sampsPerChanToAcquire = uInt64(round(sampsPerChanToAcquireAsDouble));


    //
    // Make the call
    //
    int32 status =
        DAQmxCfgImplicitTiming(
            taskHandle,
            sampleMode,
            sampsPerChanToAcquire);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxExportSignal(taskHandle, signalID, outputTerminal)
void ExportSignal(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: signalID
    int32 signalID =
        readValueArgument(nrhs, prhs, 2, "signalID");

    // prhs[3]: outputTerminal
    std::string outputTerminal =
        readMandatoryStringArgument(nrhs, prhs,
            3, "outputTerminal",
            EMPTY_IS_NOT_ALLOWED);

    //
    // Make the call
    //
    int32 status =
        DAQmxExportSignal(
            taskHandle,
            signalID, 
            outputTerminal.c_str());
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxCfgInputBuffer(taskHandle, numSampsPerChan)
void CfgInputBuffer(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: numSampsPerChan
    int index = 2;
    double numSampsPerChanAsDouble;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        numSampsPerChanAsDouble = mxGetScalar(prhs[index]);
        //mexPrintf("rate is %g\n", rate);
        if (!isfinite(numSampsPerChanAsDouble) || numSampsPerChanAsDouble < 0 || numSampsPerChanAsDouble>4294967295.0) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "numSampsPerChan must be a finite, positive value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "numSampsPerChan must be a numeric non-complex scalar");
    }
    uInt32 numSampsPerChan = uInt32(round(numSampsPerChanAsDouble));

    // Make the call
    int32 status = DAQmxCfgInputBuffer(taskHandle, numSampsPerChan);
    handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



//void printGlobalState() {
//	mexPrintf("TASK_HANDLE_COUNT: %d\n", TASK_HANDLE_COUNT);
//	for (int i = 0; i < TASK_HANDLE_COUNT; ++i) {
//		mexPrintf("TASK_HANDLES[%d]: %p\n", i, TASK_HANDLES[i]);
//	}
//
//	mexPrintf("IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED: %d\n", IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED);
//	mexPrintf("EVERY_N_SAMPLES_MATLAB_CALLBACK: %p\n", EVERY_N_SAMPLES_MATLAB_CALLBACK);
//	mexPrintf("N_SAMPLES: %ud\n", N_SAMPLES);
//	mexPrintf("EVERY_N_SAMPLES_TASK_HANDLE: %p\n", EVERY_N_SAMPLES_TASK_HANDLE);
//}
//// end of function



// DAQmxRegisterEveryNSamplesEvent(taskHandle, nSamples, callbackFunction)
void RegisterEveryNSamplesEvent(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
	//printGlobalState();

    if (IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED) {
        mexErrMsgIdAndTxt("ws:ni:callbackAlreadyRegistered", "A callback is already registered for everyNSamplesEvent");
    }

    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    // prhs[2]: nSamples
    int index = 2;
    double nSamplesAsDouble;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxIsNumeric(prhs[index]) && !mxIsComplex(prhs[index])) {
        nSamplesAsDouble = mxGetScalar(prhs[index]);
        if (!isfinite(nSamplesAsDouble) || nSamplesAsDouble < 0 || nSamplesAsDouble>4294967295.0) {
            mexErrMsgIdAndTxt("ws:ni:badArgument", "nSamples must be a finite, positive value");
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "nSamplesAsDouble must be a numeric non-complex scalar");
    }
    uInt32 nSamples = uInt32(round(nSamplesAsDouble));

    // prhs[3]: callbackFunction (the Matlab one)
    index = 3;
    const mxArray * callbackFunction=0;
    if ((nrhs>index) && mxIsScalar(prhs[index]) && mxGetClassID(prhs[index])==mxFUNCTION_CLASS) {
        callbackFunction = prhs[index];
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:badArgument", "callbackFunction must be a scalar function handle");
    }

	// Declare variable to hold error code from DAQmx calls
	int32 status;

	// Make the call
	status =
		DAQmxRegisterEveryNSamplesEvent(
			taskHandle,
			DAQmx_Val_Acquired_Into_Buffer,
			nSamples,
			DAQmx_Val_SynchronousEventCallbacks,
			&everyNSamplesCppCallback,
			(void *)(0));
	handlePossibleDAQmxErrorOrWarning(status, action);

	// If get here, that must have worked

    // Modify the globals appropriately
	EVERY_N_SAMPLES_TASK_HANDLE = taskHandle;
	N_SAMPLES = nSamples;
	EVERY_N_SAMPLES_MATLAB_CALLBACK = mxDuplicateArray(callbackFunction);
    mexMakeArrayPersistent(EVERY_N_SAMPLES_MATLAB_CALLBACK);
	//mexPrintf("About to set IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED = true\n");
	IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED = true;
		
	// Stopping the task after registering makes it work properly in repeated usage.
	// Why that might be is mysterious to me.
	status = DAQmxStopTask(taskHandle);
	handlePossibleDAQmxErrorOrWarning(status, action);
}
// end of function



// DAQmxUnregisterEveryNSamplesEvent(taskHandle)
void UnregisterEveryNSamplesEvent(std::string action, int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
    // prhs[1]: taskHandle
    TaskHandle taskHandle = readTaskHandleArgument(action, nrhs, prhs);

    if (IS_EVERY_N_SAMPLES_MATLAB_CALLBACK_REGISTERED)  {
        if (taskHandle == EVERY_N_SAMPLES_TASK_HANDLE) {
            // Unregister the callback
            const bool doIgnoreErrors = false;
            int32 status = unregisterEveryNSamplesEventAndUpdateGlobals(doIgnoreErrors);
            handlePossibleDAQmxErrorOrWarning(status, action);
        }
        else {
            std::string errorMessage = sprintfpp("No callback is registered for everyNSamplesEvent for task handle %p", taskHandle);
            mexErrMsgIdAndTxt("ws:ni:noCallbackRegisteredForTask", errorMessage.c_str());
        }
    }
    else {
        mexErrMsgIdAndTxt("ws:ni:noCallbackRegistered", "No callback is registered for everyNSamplesEvent");
    }
}
// end of function



// The entry-point, where we do dispatch
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // Dispatch on the 'method' name
    if (nrhs<1)  {
        mexErrMsgIdAndTxt("ws:ni:tooFewArguments",
                          "ws.ni() needs at least one argument") ;
    }
    
    const mxArray* actionAsMxArray = (mxArray*)(prhs[0]) ;
    if (!isMxArrayAString(actionAsMxArray))  {
        mexErrMsgIdAndTxt("ws:ni:argNotAString", 
                          "First argument to ws.ni() must be a string.") ;        
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

    if (action == "DAQmxReadBinaryI16") {
        ReadBinaryI16(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxReadAnalogF64") {
        ReadAnalogF64(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxReadDigitalLines") {
        ReadDigitalLines(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxReadDigitalU32") {
        ReadDigitalU32(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxWriteAnalogF64") {
        WriteAnalogF64(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxWriteDigitalLines") {
        WriteDigitalLines(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxIsTaskDone") {
        IsTaskDone(action, nlhs, plhs, nrhs, prhs);
    }
    else if ( action == "DAQmxCreateTask" )  {
        CreateTask(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxGetAllTaskHandles" )  {
        GetAllTaskHandles(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxClearTask" )  {
        ClearTask(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxClearAllTasks" )  {
        ClearAllTasks(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxStartTask" )  {
        StartTask(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxStopTask" )  {
        StopTask(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxTaskControl" )  {
        TaskControl(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCreateAIVoltageChan" )  {
        CreateAIVoltageChan(action, nlhs, plhs, nrhs, prhs) ;
    }    
    else if ( action == "DAQmxCreateAOVoltageChan" )  {
        CreateAOVoltageChan(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCreateDIChan" )  {
        CreateDIChan(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCreateDOChan" )  {
        CreateDOChan(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxGetReadAvailSampPerChan" )  {
        GetReadAvailSampPerChan(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxWaitUntilTaskDone" )  {
        WaitUntilTaskDone(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCfgSampClkTiming" )  {
        CfgSampClkTiming(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if ( action == "DAQmxCfgDigEdgeStartTrig" )  {
        CfgDigEdgeStartTrig(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if (action == "DAQmxDisableStartTrig") {
        DisableStartTrig(action, nlhs, plhs, nrhs, prhs);
    }
    else if ( action == "DAQmxGetAIDevScalingCoeffs" )  {
        GetAIDevScalingCoeffs(action, nlhs, plhs, nrhs, prhs) ;
    }
    else if (action == "DAQmxGetAIDevScalingCoeffs") {
        GetAIDevScalingCoeffs(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetSysDevNames") {
        GetSysDevNames(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetDevDILines") {
        GetDevDILines(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetDevCOPhysicalChans") {
        GetDevCOPhysicalChans(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetDevAIPhysicalChans") {
        GetDevAIPhysicalChans(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetDevAOPhysicalChans") {
        GetDevAOPhysicalChans(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetDevBusType") {
        GetDevBusType(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetRefClkSrc") {
        GetRefClkSrc(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxSetRefClkSrc") {
        SetRefClkSrc(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxGetRefClkRate") {
        GetRefClkRate(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxSetRefClkRate") {
        SetRefClkRate(action, nlhs, plhs, nrhs, prhs);
    }
	else if (action == "DAQmxGetSampClkRate") {
		GetSampClkRate(action, nlhs, plhs, nrhs, prhs);
	}
    else if (action == "DAQmxGetBufOutputBufSize") {
        GetBufOutputBufSize(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxCfgOutputBuffer") {
        CfgOutputBuffer(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxResetWriteRelativeTo") {
        ResetWriteRelativeTo(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxResetWriteOffset") {
        ResetWriteOffset(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxCreateCOPulseChanFreq") {
        CreateCOPulseChanFreq(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxCfgImplicitTiming") {
        CfgImplicitTiming(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxExportSignal") {
        ExportSignal(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxCfgInputBuffer") {
        CfgInputBuffer(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxRegisterEveryNSamplesEvent") {
        RegisterEveryNSamplesEvent(action, nlhs, plhs, nrhs, prhs);
    }
    else if (action == "DAQmxUnregisterEveryNSamplesEvent") {
        UnregisterEveryNSamplesEvent(action, nlhs, plhs, nrhs, prhs);
    }
    else  {
        // Doesn't match anything, so error
        std::string errorMessage = sprintfpp("ws.ni() doesn't recognize method name %s", action.c_str());
        mexErrMsgIdAndTxt("ws:ni:noSuchMethod",
                          errorMessage.c_str()) ;
    }

    //mexPrintf("About to exit\n");
}
// end of function

