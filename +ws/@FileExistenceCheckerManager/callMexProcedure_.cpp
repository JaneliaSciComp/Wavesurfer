#include <stdlib.h>
#include <math.h>
#include <windows.h>
#include <process.h>
#include <mex.h>

typedef UINT64 uint64 ;
//#define DWORD_MAX 4294967295  // ==2^32-1

// Need to hold our special window id in a static variable, so we can set it in the mex function.
// And then get it in the hook function.
//const uint64 N_SLOTS = 32 ;  // this is the maximum number of FileExistenceCheckers that can be created in a single Matlab session
//bool HAVE_GLOBALS_BEEN_INITIALIZED = false ;  // If the DLL gets cleared, this should be false when it is invoked again, so we can set up properly
//bool IS_SLOT_IN_USE[N_SLOTS] ;
//uint64 N_SLOTS_IN_USE = 0 ;  // the number of random timers currently in existance
//mxArray* CALLBACKS[N_SLOTS] ; 
  // Each timer's unique ID (UID) is the index of the slot it occupies
UINT FECM_WINDOW_MESSAGE_ID = 0 ;  
  // this has to be a C/C++ global, b/c need to access in the hook procedure
  // If the DLL gets cleared, this should be 0 when it is invoked again, so we can set up properly
//HHOOK HOOK_HANDLE = NULL ;

typedef struct  {
    DWORD mainThreadId ;
    HANDLE endChildThreadEventHandle ;
    uint64 UID ;
	char* filePath ;
    //UINT FECM_WINDOW_MESSAGE_ID ;
} ChildThreadArguments ;

double round(double x)  {
    // VS2008 doesn't seem to include an implementation of this...
    double result ;
    if (x==0.0)  {
        result = x ;
    }
    else {            
        if (x>0.0)  {
            // x is positive
            double floor_x = floor(x) ;
            double frac_x = x - floor_x ;
            // We follow the "round to nearest, ties away from zero" convention (although this is not the ieee 754 default...)
            if (frac_x<0.5)  {
                result = floor_x ;
            }
            else {
                result = ceil(x) ;
            }
        }
        else  {
            // x is negative
            result = -round(-x) ;
              // this should be "lossless", right?  There's a single sign bit in IEEE 754.
        }
    }
    return result ;
}

/*
double unifrnd()  {
    // Generates a uniform random number on [0,1].
    // This is probably a crappy random number in lots of ways.
    return double(rand())/double(RAND_MAX) ;
}

double exprnd(double rate)  {
    // Generate a random variable drawn from an exponential distribution with rate parameter rate.
    // The expectation of this R.V. is 1/rate.  The variance is 1/(rate^2).
    return -log(unifrnd())/rate ;
}
*/

void handleWindowsError(uint64 code, const char* procedureName)  {
    if (code==0)  {
        DWORD err = GetLastError() ;
        const int bufferSize = 2048 ;
        char buffer[bufferSize] ;
        sprintf_s(buffer, bufferSize, "Winapi error in call to %s, error code %d", procedureName, err) ;
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:errorInWinapiCall", 
                          buffer) ;        
    }
}

bool isMxArrayAUint64Scalar(const mxArray* arg)  {
    return mxGetClassID(arg)==mxUINT64_CLASS && mxGetNumberOfDimensions(arg)==2 && mxGetM(arg)==1 && mxGetN(arg)==1 ;
}

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
    uint64 m = (uint64)(mxGetM(arg)) ;
    uint64 n = (uint64)(mxGetN(arg)) ;
    bool isRowVector = (m==1) ;
    bool isZeroByZero = (m==0)&&(n==0) ;
    return (isRowVector || isZeroByZero) ;
}

mxArray* mxCreateUint64Scalar(uint64 newValue)  {
    mxArray* newValueAsMxArray = mxCreateNumericMatrix(1, 1, mxUINT64_CLASS, mxREAL) ;
    uint64* newValueAsMxArrayStoragePointer = (uint64*)(mxGetData(newValueAsMxArray)) ;
    *newValueAsMxArrayStoragePointer = newValue ;
    return newValueAsMxArray ;
}

uint64 mxGetUint64Scalar(const mxArray* valueAsMxArray)  {
    uint64* buffer = (uint64*)(mxGetData(valueAsMxArray)) ;
    uint64 value = (uint64)(buffer[0]) ;
    return value ;
}

void mxSetPropertyToUint64Scalar(mxArray* self, const char* propertyName, uint64 newValue)  {    
    mxArray* newValueAsMxArray = mxCreateNumericMatrix(1, 1, mxUINT64_CLASS, mxREAL) ;
    uint64* newValueAsMxArrayStoragePointer = (uint64*)(mxGetData(newValueAsMxArray)) ;
    *newValueAsMxArrayStoragePointer = newValue ;
    mxSetProperty(self, 0, propertyName, newValueAsMxArray);
    mxDestroyArray(newValueAsMxArray) ;
}

uint64 mxGetUint64ScalarProperty(mxArray* self, const char* propertyName)  {
	mxArray *propertyAsMxArrayPointer = mxGetProperty(self, 0, propertyName) ;
    uint64* propertyStoragePointer = (uint64*)(mxGetData(propertyAsMxArrayPointer)) ;
    uint64 value = *propertyStoragePointer ;
    mxDestroyArray(propertyAsMxArrayPointer) ;  // mxGetProperty makes a copy, so this is fitting and proper
    return value ;
}

bool mxGetLogicalScalarProperty(mxArray* self, const char* propertyName)  {
	mxArray *propertyAsMxArrayPointer = mxGetProperty(self, 0, propertyName) ;
    mxLogical* propertyStoragePointer = (mxLogical*)(mxGetData(propertyAsMxArrayPointer)) ;
    mxLogical value = *propertyStoragePointer ;
    mxDestroyArray(propertyAsMxArrayPointer) ;  // mxGetProperty makes a copy, so this is fitting and proper
    return bool(value) ;
}

void mxSetPropertyToLogicalScalar(mxArray* self, const char* propertyName, bool newValue)  {    
    mxArray *newValueAsMxArray = mxCreateLogicalScalar(mxLogical(newValue)) ;
    mxSetProperty(self, 0, propertyName, newValueAsMxArray);
    mxDestroyArray(newValueAsMxArray) ;  // mxSetProperty makes a copy, so this is fitting and proper
}

uint64 getTickFrequency()  {
    LARGE_INTEGER frequency;        // ticks per second
    QueryPerformanceFrequency(&frequency) ;
    return uint64(frequency.QuadPart) ;
}

uint64 getTimeInTicks()  {
    LARGE_INTEGER ticks ;
    QueryPerformanceCounter(&ticks) ;
    return uint64(ticks.QuadPart) ;
}

/*
uint64 exprndInTicks(double rate, uint64 tickFrequency)  {
    double interval = exprnd(rate) ;  // s
    double intervalInTicks = double(tickFrequency) * interval ;
    uint64 intervalInTicksAsUint64 = uint64(round(intervalInTicks)) ;    
    return intervalInTicksAsUint64 ;
}
*/

bool doesFileExistQ(char* path)  {
  DWORD dwAttrib = GetFileAttributes(path);
  bool result = (dwAttrib != INVALID_FILE_ATTRIBUTES) ;
  return result ;
}

void getFileAttributes(bool* doesFileExistPtr, FILETIME* modTimePtr, uint64* fileSizePtr, char* path)  {
    // These are the outputs, and their fall-through values
    bool doesFileExist = false ;
    FILETIME modTime ;
    uint64 fileSize ;
    
    doesFileExist = doesFileExistQ(path) ;
    if (doesFileExist)  {        
        HANDLE fileHandle = CreateFile(path, 
                                       GENERIC_READ, 
                                       FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                       NULL, 
                                       OPEN_EXISTING,
                                       FILE_ATTRIBUTE_NORMAL,
                                       NULL) ;
        if (fileHandle==INVALID_HANDLE_VALUE)  {
            doesFileExist = false ;
        }
        else {
            BOOL didSucceed = GetFileTime(fileHandle, NULL, &modTime, NULL) ; 
            if (didSucceed)  {
                LARGE_INTEGER fileSizeAsLargeInteger;
                BOOL didSucceed2 =  GetFileSizeEx(fileHandle, &fileSizeAsLargeInteger) ;
                if (didSucceed2)  {                
                    fileSize = fileSizeAsLargeInteger.QuadPart ;
                }
                else  {
                    // If there's a problem getting the file size, pretend the file doesn't exist
                    doesFileExist = false ;                
                }
            }
            else  {
                // If there's a problem getting the file time, pretend the file doesn't exist
                doesFileExist = false ;
            }
            CloseHandle(fileHandle) ;
        }
    }
    
    // Write the output locations
    *doesFileExistPtr = doesFileExist ;
    *modTimePtr = modTime ;
    *fileSizePtr = fileSize ;
}

bool mallocedStringFromMxArray(char** stringPointer, const mxArray* stringAsMxArrayPointer)  {
    // On exit, string pointer points to a char* that points to a heap-allocated (via mxMalloc) 
    // buffer holding the string from stringAsMxArray.  
    // Returns true if successful, false otherwise.

    /*
    // Check that stringAsMxArray is a proper Matlab string
    if ( mxGetClassID(stringAsMxArrayPointer)!=mxCHAR_CLASS )  {
        *stringPointer = (char*)(0) ;  // For tidiness
        return false;
    }
    
    // Check that stringAsMxArray is 2D
    if ( mxGetNumberOfDimensions(stringAsMxArrayPointer)!=2 )  {
        *stringPointer = (char*)(0) ;  // For tidiness
        return false;
    }
    
    // Check that stringAsMxArray is either 0x0 or 1xn, for natural n
    uint64 m = (uint64)(mxGetM(stringAsMxArrayPointer)) ;
    uint64 stringLength = (uint64)(mxGetN(stringAsMxArrayPointer)) ;
    bool isRowVector = (m==1) ;
    bool isZeroByZero = (m==0)&&(stringLength==0) ;
    if (!isRowVector && !isZeroByZero)  {
        *stringPointer = (char*)(0) ;  // For tidiness
        return false;        
    }
        
    // If get here, all is well with stringAsMxArray: It's a proper Matlab string
    */
    
    // Allocate a buffer to hold the string, using *malloc*, not mxMalloc()
    uint64 stringLength = (uint64)(mxGetN(stringAsMxArrayPointer)) ;
    uint64 bufferSize = stringLength+1 ;
    char* buffer = (char*)(malloc(bufferSize));  // char's are *always* one byte
    if (!buffer)  {
        // Unable to allocate space, apparently
        *stringPointer = (char*)(0) ;  // For tidiness
        return false;                
    }
    
    // Copy the data out from the Matlab string to the C-style string
    int didFail = mxGetString(stringAsMxArrayPointer, buffer, bufferSize) ;
    if (didFail)  {
        free(buffer) ;  // Important for clean exit
        *stringPointer = (char*)(0) ;  // For tidiness
        return false;                        
    }
    
    // Exit, covered in glory
    *stringPointer = buffer ;
    return true ;
}

LRESULT CALLBACK theHookProcedure(int code, WPARAM wParam, LPARAM lParam)  {    
    //mexPrintf("At theHookProcedure() point 1\n") ;
    
    // Only fire the callback is this the the message actually being taken
    // out of the queue.  Don't want to fire the callback if someone is merely 
    // peeking at the message.
    // Without this, the callback can get called multiple times per PostThreadMessage() call, 
    // especially if the main Matlab thread is doing something CPU intensive.
    if (wParam==PM_REMOVE)  {
        MSG* msgPointer = (MSG*)(lParam) ;
        UINT msgID = msgPointer->message ;

        if (msgID==FECM_WINDOW_MESSAGE_ID)  {
            // This is the custom message, so we call the callback
            //mexPrintf("In theHookProcedure() point 2, got a matching message.\n") ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xffffffffffffffff) ) ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xfeffffffffffffff) ) ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xf000000000000000) ) ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xf00000000a000000) ) ;

            // Report what the last interval was
            WPARAM uidAsWPARAM = msgPointer->wParam ;
            //mexPrintf("In theHookProcedure(), last interval was not: %llu\n", (uint64)(0xffffffffffffffff) ) ;           
            uint64 uid = (uint64)(uidAsWPARAM) ;
            //mexPrintf("In theHookProcedure(), uid is: %llu\n", uid) ;                       
            
            mxArray* fecm ;

            mxArray* exceptionMxArray = mexCallMATLABWithTrap(1, &fecm, 0, (mxArray**)(0), "ws.FileExistenceCheckerManager.getShared") ;

            if (exceptionMxArray)  {
                mxArray *messageAsMxArray = mxGetProperty(exceptionMxArray, 0, "message") ;
                char* message = mxArrayToString(messageAsMxArray) ;  // Space for this string is allocated with mxMalloc()
                mexPrintf("ws.FileExistenceCheckerManager hook procedure errored when calling ws.FileExistenceCheckerManager.getShared() via mexCallMATLABWithTrap(): %s\n", message ) ;            
                mxFree(message) ;
                mxDestroyArray(messageAsMxArray) ;  // I think this is what I should be doing...
            }
            else  {
                mxArray* uidAsMxArray = mxCreateUint64Scalar(uid) ;

                mxArray* args[2] ;
                args[0] = fecm ;    
                args[1] = uidAsMxArray ;

                mxArray *exceptionMxArray2 = mexCallMATLABWithTrap(0, (mxArray**)(0), 2, args, "callCallback") ;

                if (exceptionMxArray2)  {
                    mxArray *messageAsMxArray = mxGetProperty(exceptionMxArray, 0, "message") ;
                    char* message = mxArrayToString(messageAsMxArray) ;  // Space for this string is allocated with mxMalloc()
                    mexPrintf("ws.FileExistenceCheckerManager hook procedure errored when calling ws.FileExistenceCheckerManager::callCallback() via mexCallMATLABWithTrap(): %s\n", message ) ;            
                    mxFree(message) ;
                    mxDestroyArray(messageAsMxArray) ;  // I think this is what I should be doing...
                }    
                
                // Need to free stuff here
                mxDestroyArray(uidAsMxArray) ;
                mxDestroyArray(fecm) ;  // is this right?  Or is this going to break stuff?
            }
        }
    }
    return CallNextHookEx(0, code, wParam, lParam) ; 
}

unsigned int childThreadProcedure(void* lpParameter)  {
	// Get args, delete the memory used for them
	ChildThreadArguments* threadArgumentsPointer = (ChildThreadArguments*)(lpParameter) ;
    DWORD mainThreadId = threadArgumentsPointer->mainThreadId ;
    HANDLE endChildThreadEventHandle = threadArgumentsPointer->endChildThreadEventHandle ;
    uint64 UID = threadArgumentsPointer->UID ;
	char* filePath = threadArgumentsPointer->filePath ;    
    
    // Free the thread args pointer
	free(threadArgumentsPointer) ;
	threadArgumentsPointer = 0 ;  // zero for self-protection
    
    // Debug: Fire the callback just to show that that works.
    //PostThreadMessage(mainThreadId, FECM_WINDOW_MESSAGE_ID, (WPARAM)(0), (LPARAM)(callbackAsMxArrayPointer)) ;
    
    // The rate at which we check for the command file
    double rate = 10.0 ;  // Hz
    
    // Set initial values for file attributes from the "last" check.
    // We pretend the file did not exist the last time it was checked, b/c we
    // want the callback to fire if the file already exists.
    bool didFileExistAtLastCheck = false ;  // Want the callback to fire if the file already exists
    FILETIME fileModTimeAtLastCheck ;
    uint64 fileSizeAtLastCheck ;    
    
    // Get the tick frequency
    uint64 tickFrequency = getTickFrequency() ;  // Hz
    
    // Get an initial interval, and convert to ticks
    //uint64 intervalInTicks = exprndInTicks(rate, tickFrequency) ; 
    uint64 intervalInTicks = (uint64)(round(double(tickFrequency)/rate)) ;     
    
    // Get the initial time, in ticks since some reference time
    uint64 intervalStartTime = getTimeInTicks() ;
    while (true)  {
        // Get the elapsed time since the interval start
        uint64 elapsedTicks = getTimeInTicks() - intervalStartTime ;
        
        // Check for a stop event signal
        DWORD waitResult = WaitForSingleObject(endChildThreadEventHandle, 0) ;  // wait that many ms
        if (waitResult == WAIT_OBJECT_0)  {
            // This means the parent thread has signaled the child to stop
            break ;
        }
        
        // If enough ticks, check for the file, then start a new interval
        if ( elapsedTicks >= intervalInTicks )  {
            // Get the file attributes
            bool doesFileExist ;
            FILETIME fileModTime ;
            uint64 fileSize ;
            getFileAttributes(&doesFileExist, &fileModTime, &fileSize, filePath) ;
            
            // If something has changed, post a message to the parent thread
            if (doesFileExist!=didFileExistAtLastCheck || CompareFileTime(&fileModTime, &fileModTimeAtLastCheck)!=0 || fileSize!=fileSizeAtLastCheck)  {
                // Post the message that will eventually fire the Matlab callback on the main thread
                // The fourth arg here will end up as the lParam of the message, so we can use it to pass data.
                PostThreadMessage(mainThreadId, FECM_WINDOW_MESSAGE_ID, (WPARAM)(UID), (LPARAM)(0)) ;
            }
            
            // Set these to be ready for the next check
            didFileExistAtLastCheck = doesFileExist ;
            fileModTimeAtLastCheck = fileModTime ;
            fileSizeAtLastCheck = fileSize ;
            
            // Reset the reference time
            intervalStartTime = getTimeInTicks() ;
        }
        else  {
            // This won't be super-accurate, but that's OK
            Sleep(1) ;  // Sleep(0) causes the thread to peg a CPU, but this prevents that
        }
    }
	
    // Free the filePath, which was malloced on the main thread
    free(filePath) ;
    filePath = (char*)(0) ;
    
	// Return success
	return 0 ;
}

void initialize(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
    // This should be called by the FileExistenceChecker constructor
    
    // Make sure enough LHS vars to hold our output
    /*
    if (nlhs<1) {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:notEnoughInitializeArgs", 
                          "Initialize needs exactly one output argument") ;        
    }
    */
    
    // Get a Windows message ID, store in the global
    // Only get one if there isn't one already
    if (FECM_WINDOW_MESSAGE_ID==0)  {
        UINT messageId = RegisterWindowMessage("FileExistenceCheckerManager_kjsghdfueiu38y47") ;
            // Can't use WM_APP+0, WM_APP+1, etc b/c Matlab might be using those already
        handleWindowsError(messageId, "RegisterWindowMessage") ;
        FECM_WINDOW_MESSAGE_ID = messageId ;  // only set the global if no error
    }
    
    // Register a hook function on the current thread (the main Matlab thread)
    HHOOK hookHandle = SetWindowsHookEx(WH_GETMESSAGE, &theHookProcedure, NULL, GetCurrentThreadId()) ;    
    handleWindowsError((uint64)(hookHandle), "SetWindowsHookEx") ;
    //mexPrintf("In FileExistenceChecker::initialize(), about to lock the DLL\n") ;

    // Keep this DLL in process, so that the child thread procedure and the hook procedure stay in memory
    mexLock() ;        

    // Store the outputs
    //plhs[0] = mxCreateUint64Scalar(FECM_WINDOW_MESSAGE_ID) ;
    plhs[0] = mxCreateUint64Scalar((uint64)(hookHandle)) ;
}

void start(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
	//
	// Read input arguments
	//
    
    // Make sure enough input args
    if (nrhs!=3) {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:notEnoughStartArgs", 
                          "Start needs exactly three input arguments") ;        
    }

    // Make sure enough output args
    if (nlhs!=4) {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:notEnoughStartOutputArgs", 
                          "Start needs exactly four output arguments") ;        
    }        
    
	// prhs[1]
	const mxArray* uidAsMxArray = prhs[1] ;
    if (!isMxArrayAUint64Scalar(uidAsMxArray))  {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:start:argNotUint64Scalar", 
                          "Second arg to a start call (the UID) must be a uint64 scalar") ;        

    }
    uint64 uid = mxGetUint64Scalar(uidAsMxArray) ;
    //mexPrintf("At FECM::start(), uid = %lld\n", uid) ;

	// prhs[2]
	const mxArray *filePathAsMxArrayPointer = prhs[2] ;
    if (!isMxArrayAString(filePathAsMxArrayPointer))  {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:start:argNotAString", 
                          "Third arg to a start call (the filePath) must be a string") ;        
    }
    char *filePath ;  // this will be allocated on the heap with mxMalloc(), but will be released when mexFunction returns, which is OK, 
                             // because we make a copy in the child thread
    bool didSucceed = mallocedStringFromMxArray(&filePath, filePathAsMxArrayPointer) ;
    if (!didSucceed)  {
        mexErrMsgIdAndTxt("FileExistenceChecker:unableToCopyFilePath", 
                          "Unable to start the FileExistenceChecker (unable to create a C string on the heap from the FilePath)") ;        
    }    
            
//     // prhs[3]: callbackWindowMessageId
// 	const mxArray* callbackWindowMessageIdAsMxArray = prhs[3] ;
//     UINT callbackWindowMessageId = mxGetUint64Scalar(callbackWindowMessageIdAsMxArray) ;    
    
    // Create an event that we will use to tell the child thread to exit when the FileExistenceChecker is stopped
    HANDLE endChildThreadEventHandle = 
        CreateEvent(NULL,               // default security attributes
                    TRUE,               // manual-reset event
                    FALSE,              // initial state is nonsignaled
                    NULL                // object name, which we don't want b/c want all these events to be independent
                    ) ; 
    if ( endChildThreadEventHandle == NULL )  {
        mexErrMsgIdAndTxt("FileExistenceChecker:unableToCreateEndChildThreadEvent", 
                          "Unable to start the FileExistenceChecker (unable to create Windows event for stopping child thread)") ;
    }
    
    // Store the handle for the event in self
    //mxSetPropertyToUint64Scalar(self, "EndChildThreadEventHandle_", (uint64)(endChildThreadEventHandle)) ;
    
    // Package up the child thread arguments	
	ChildThreadArguments* childThreadArgumentsPointer = (ChildThreadArguments*)(malloc(sizeof(ChildThreadArguments))) ;  
    childThreadArgumentsPointer->mainThreadId = GetCurrentThreadId() ;
    childThreadArgumentsPointer->endChildThreadEventHandle = endChildThreadEventHandle ;
	childThreadArgumentsPointer->UID = uid ;
    childThreadArgumentsPointer->filePath = filePath ;
    //childThreadArgumentsPointer->callbackWindowMessageId = callbackWindowMessageId ;    
	
    //mexPrintf("At RandomThread::start() point 5, about to start child thread with endChildThreadEventHandle = %lld\n", endChildThreadEventHandle) ;
    
    // Spawn the child thread
	HANDLE threadHandle = (HANDLE)(_beginthreadex(NULL, 0, &childThreadProcedure, childThreadArgumentsPointer, 0, NULL)) ;

    //mexPrintf("At RandomThread::start() point 6\n") ;
    
    // Get the child thread ID, mostly so we can look for it in process explorer if need be
    DWORD threadId = GetThreadId(threadHandle) ;
    
    // Return the outputs: isRunning, threadHandle, threadID, endChildThreadEventHandle; in that order    
    plhs[0] = mxCreateLogicalScalar(true) ;
    plhs[1] = mxCreateUint64Scalar((uint64)(threadHandle)) ;
    plhs[2] = mxCreateUint64Scalar((uint64)(threadId)) ;
    plhs[3] = mxCreateUint64Scalar((uint64)(endChildThreadEventHandle)) ;
    
    //mexPrintf("At RandomThread::start() point 8, about to exit\n") ;
}

void stop(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
    // Make sure enough input args
    if (nrhs!=5) {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:notEnoughStopArgs", 
                          "Stop needs exactly five input arguments") ;        
    }

    /*
    // Make sure enough output args
    if (nlhs!=4) {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:notEnoughStartOutputArgs", 
                          "Stop needs exactly four output arguments") ;        
    }        
    */
    
    // Input args: uid, fec.ThreadHandle, fec.ThreadID, fec.EndChildThreadEventHandle
    
    // prhs[1]: UID
	const mxArray* uidAsMxArray = prhs[1] ;
    uint64 uid = mxGetUint64Scalar(uidAsMxArray) ;
    
    // prhs[2]: threadHandle
	const mxArray* threadHandleAsMxArray = prhs[2] ;
    HANDLE threadHandle = (HANDLE)(mxGetUint64Scalar(threadHandleAsMxArray)) ;

    // prhs[3]: threadId
    const mxArray* threadIdAsMxArray = prhs[3] ;
    DWORD threadId = (DWORD)(mxGetUint64Scalar(threadIdAsMxArray)) ;
	
    // prhs[4]: endChildThreadEventHandle
    const mxArray* endChildThreadEventHandleAsMxArray = prhs[4] ;
    HANDLE endChildThreadEventHandle = (HANDLE)(mxGetUint64Scalar(endChildThreadEventHandleAsMxArray)) ;   

    //mexPrintf("In RandomThread::stop(), about to stop child thread with endChildThreadEventHandle = %lld\n", endChildThreadEventHandle) ;    
    
    // Tell the child thread to stop
    BOOL didThatWork = SetEvent(endChildThreadEventHandle) ;
    if (!didThatWork)  {
        mexErrMsgIdAndTxt("FileExistenceChecker:unableToStopChildThread", 
                          "Unable to stop the FileExistenceChecker (SetEvent failed)") ;  
    }    
    
    // Wait for the child thread to terminate
    DWORD waitResult = WaitForSingleObject(threadHandle, 500) ;  // wait that many ms
    if (waitResult != WAIT_OBJECT_0)  {
        mexErrMsgIdAndTxt("FileExistenceChecker:childThreadFailedToStop", 
                          "Unable to stop the FileExistenceChecker (child thread failed to stop within timeout)") ;
    }

    //mexPrintf("In RandomThread::stop(), child thread seems to have stopped.\n") ;        

    // Now close the thread handle, which apparently we have to do b/c we started it with _beginthreadex()
    BOOL didThatWork2 = CloseHandle(threadHandle) ;  // this returns a bool indicating success/failure, but not sure what I would do if it failed
    if (!didThatWork2)  {
        mexWarnMsgIdAndTxt("FileExistenceChecker:unableToCloseChildThreadHandle", 
                           "Unable to stop the FileExistenceChecker cleanly (CloseHandle failed)") ;  
    }    

    //mexPrintf("In RandomThread::stop(), successfully closed child thread handle.\n") ;        
    
    // Release the event handle
    BOOL didThatWork3 = CloseHandle(endChildThreadEventHandle) ;
    if (!didThatWork)  {
        // What to do here?  Try again?  Proceed like all is well?
        mexErrMsgIdAndTxt("FileExistenceChecker:unableToReleaseEvent", 
                          "Unable to stop the FileExistenceChecker cleanly, may be in a weird state and/or have leaked resources (CloseHandle failed)") ;
    }

    // Return the output: isRunning
    plhs[0] = mxCreateLogicalScalar(false) ;
}

void finalize(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
    // This should be called by the FileExistenceCheckerManager delete() method.
    
    //mexPrintf("In RandomThread::finalize()\n") ;        
    
    //self.WindowMessageID_, self.HookHandle_
    // Make sure enough input args
    if (nrhs!=2) {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:notEnoughFinalizeArgs", 
                          "Finalize needs exactly two input arguments") ;        
    }
    
    // Input args: windowMessageID, hookHandle
    
    // prhs[1]: hookHandle
	const mxArray* hookHandleAsMxArray = prhs[1] ;
    if (!isMxArrayAUint64Scalar(hookHandleAsMxArray))  {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:finalize:argNotUint64Scalar", 
                          "Second arg to a finalize call (the hook handle) must be a uint64 scalar") ;        

    }
    HHOOK hookHandle = (HHOOK)(mxGetUint64Scalar(hookHandleAsMxArray)) ;
        
    // Unregister the hook and release it
    //mexPrintf("In RandomThread::finalize(), about to unregister the hook and unlock the DLL\n") ;

    // Unregister the hook function
    BOOL didThatWork = UnhookWindowsHookEx(hookHandle) ;
    if (!didThatWork)  {
        // What to do here?  Try again?  Proceed like all is well?
        mexWarnMsgIdAndTxt("FileExistenceChecker:unableToRemoveHook", 
                           "Unable to remove the Windows hook, DLL may be in a weird state and/or have leaked resources (UnhookWindowsHookEx failed)") ;
    }

    // Allow this DLL to be cleared, if needed or requested
    mexUnlock() ;        
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // Dispatch on the method name
    if (nrhs<1)  {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:callMexMethod_:tooFewArguments",
                          "FileExistenceCheckerManager::callMexMethod_() needs at least one arguments") ;
    }
    
	const mxArray* actionAsMxArray = (mxArray*)(prhs[0]) ;
    if (!isMxArrayAString(actionAsMxArray))  {
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:argNotAString", 
                          "First argument to callMexProcedure_() must be a string.") ;        
    }

    char* action = mxArrayToString(actionAsMxArray) ;  // Do I need to free this?
    if ( strcmp(action,"initialize")==0 )  {
        initialize(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"start")==0 )  {
        start(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"stop")==0 )  {
        stop(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(action,"finalize")==0 )  {
        finalize(nlhs, plhs, nrhs, prhs) ;
    }
    else  {
        // Doesn't match anything, so error
        mexErrMsgIdAndTxt("FileExistenceCheckerManager:callMexProcedure_:noSuchMethod",
                          "FileExistenceCheckerManager::callMexProcedure_() doesn't recognize that method name") ;
    }
}
