#include <stdlib.h>
#include <math.h>
#include <windows.h>
#include <process.h>
#include <mex.h>

typedef UINT64 uint64 ;
//#define DWORD_MAX 4294967295  // ==2^32-1

// Need to hold our special window id in a static variable, so we can set it in the mex function.
// And then get it in the hook function.
const uint64 N_SLOTS = 32 ;  // this is the maximum number of FileExistenceCheckers that can be created in a single Matlab session
bool HAVE_GLOBALS_BEEN_INITIALIZED = false ;  // If the DLL gets cleared, this should be false when it is invoked again, so we can set up properly
bool IS_SLOT_IN_USE[N_SLOTS] ;
uint64 N_SLOTS_IN_USE = 0 ;  // the number of random timers currently in existance
mxArray* CALLBACKS[N_SLOTS] ; 
  // Each timer's unique ID (UID) is the index of the slot it occupies
UINT CALLBACK_WINDOW_MESSAGE_ID = 0 ;
HHOOK HOOK_HANDLE = NULL ;

typedef struct  {
    DWORD mainThreadId ;
    HANDLE endChildThreadEventHandle ;
	mxArray* callbackAsMxArrayPointer ;
	char* filePath ;
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

uint64 exprndInTicks(double rate, uint64 tickFrequency)  {
    double interval = exprnd(rate) ;  // s
    double intervalInTicks = double(tickFrequency) * interval ;
    uint64 intervalInTicksAsUint64 = uint64(round(intervalInTicks)) ;    
    return intervalInTicksAsUint64 ;
}

bool doesFileExistQ(char* path)  {
  DWORD dwAttrib = GetFileAttributes(path);
  bool result = (dwAttrib != INVALID_FILE_ATTRIBUTES) ;
  return result ;
}

bool mallocedStringFromMxArray(char** stringPointer, const mxArray* stringAsMxArrayPointer)  {
    // On exit, string pointer points to a char* that points to a heap-allocated (via mxMalloc) 
    // buffer holding the string from stringAsMxArray.  
    // Returns true if successful, false otherwise.
    
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
    
    // Allocate a buffer to hold the string, using *malloc*, not mxMalloc()
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

        if (msgID==CALLBACK_WINDOW_MESSAGE_ID)  {
            // This is the custom message, so we call the callback
            mexPrintf("In theHookProcedure() point 2, got a matching message.\n") ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xffffffffffffffff) ) ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xfeffffffffffffff) ) ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xf000000000000000) ) ;
            //mexPrintf("Testing uint64 printing: 0x%016llx\n", (uint64)(0xf00000000a000000) ) ;

            // Report what the last interval was
            WPARAM intervalInMsec = msgPointer->wParam ;
            //mexPrintf("In theHookProcedure(), last interval was not: %llu\n", (uint64)(0xffffffffffffffff) ) ;           
            mexPrintf("In theHookProcedure(), last interval was: %llu\n", (uint64)(intervalInMsec) ) ;           
            
            // We've stashed the callback pointer into the lParam of the message in the call to PostThreadMessage.
            // So we get it out now.
            mxArray* callbackAsMxArrayPointer = (mxArray*)(msgPointer->lParam) ;	
            mexPrintf("In theHookProcedure(), callback pointer: 0x%016llx\n", (uint64)(callbackAsMxArrayPointer) ) ;

            // Inspect callbackAsMxArrayPointer, to make sure it's a function
            const char *className = mxGetClassName(callbackAsMxArrayPointer) ;
            mexPrintf("In theHookProcedure(), the class of callbackAsMxArrayPointer is %s\n", className) ;                
            // Do I need to free className?

            // And finally the callback call.
            mxArray *exceptionMxArray = mexCallMATLABWithTrap(0, (mxArray**)(0), 1, &callbackAsMxArrayPointer, "feval") ;
            //mexPrintf("In theHookProcedure(), mexCallMATLABWithTrap result: 0x%016llx\n", (uint64)(exceptionMxArray) ) ;        

            if (exceptionMxArray)  {
                mxArray *messageAsMxArray = mxGetProperty(exceptionMxArray, 0, "message") ;
                char* message = mxArrayToString(messageAsMxArray) ;  // Space for this string is allocated with mxMalloc()
                mexPrintf("In theHookProcedure(), mexCallMATLABWithTrap result error message: %s\n", message ) ;            
                //mxFree(message) ;
                //mxFree(messageAsMxArray) ;  // I think this is what I should be doing...
            }
        }
    }
    return CallNextHookEx(0, code, wParam, lParam) ; 
}

unsigned int childThreadProcedure(void* lpParameter)  {
	// Get args, delete the memory used for them
	ChildThreadArguments* threadArgumentsPointer = (ChildThreadArguments*)(lpParameter) ;
	char* filePath = threadArgumentsPointer->filePath ;
	mxArray* callbackAsMxArrayPointer = threadArgumentsPointer->callbackAsMxArrayPointer ;
    DWORD mainThreadId = threadArgumentsPointer->mainThreadId ;
    HANDLE endChildThreadEventHandle = threadArgumentsPointer->endChildThreadEventHandle ;
        
    // Free the thread args pointer
	free(threadArgumentsPointer) ;
	threadArgumentsPointer = 0 ;  // zero for self-protection
    
    // Debug: Fire the callback just to show that that works.
    //PostThreadMessage(mainThreadId, CALLBACK_WINDOW_MESSAGE_ID, (WPARAM)(0), (LPARAM)(callbackAsMxArrayPointer)) ;
    
    // The rate at which we check for the command file
    bool didFileExistAtLastCheck = false ;  // Want the callback to fire if the file already exists
    double rate = 10.0 ;  // Hz
    
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
        if (elapsedTicks>=intervalInTicks)  {
            
            bool doesFileExist = doesFileExistQ(filePath) ;
            if (doesFileExist && !didFileExistAtLastCheck)  {                
                // Post the message that will eventually fire the Matlab callback on the main thread
                // The fourth arg here will end up as the lParam of the message, so we can use it to pass data.
                PostThreadMessage(mainThreadId, CALLBACK_WINDOW_MESSAGE_ID, (WPARAM)(0), (LPARAM)(callbackAsMxArrayPointer)) ;
            }
            
            // Set this to be ready for the next check
            didFileExistAtLastCheck = doesFileExist ;
            
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
    filePath = 0 ;
    
	// Return success
	return 0 ;
}

void initialize(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
    // This should be called by the FileExistenceChecker constructor
    
    // If this is the first call into the DLL, initialize the DLL globals
    if (!HAVE_GLOBALS_BEEN_INITIALIZED)  {
        for (uint64 i=0; i<N_SLOTS; ++i)  {
            IS_SLOT_IN_USE[i] = false ;
            CALLBACKS[N_SLOTS] = (mxArray*)(0) ;  // for my own protection            
        }
        N_SLOTS_IN_USE = 0 ;
        
        // Get a Windows message ID
        CALLBACK_WINDOW_MESSAGE_ID = RegisterWindowMessage("FileExistenceChecker_kjsghdfueiu38y47") ;
          // Can't use WM_APP+0, WM_APP+1, etc b/c Matlab might be using those already
        
        HAVE_GLOBALS_BEEN_INITIALIZED = true ;
    }
    
    // If this is the first timer to be created (or there have been zero timers 
    // for a while, and now one is being created), need to do some stuff
    if (N_SLOTS_IN_USE==0)  {
        // Register a hook function on the current thread (the main Matlab thread)
        HOOK_HANDLE = SetWindowsHookEx(WH_GETMESSAGE, &theHookProcedure, NULL, GetCurrentThreadId()) ;        
        
        mexPrintf("In FileExistenceChecker::initialize(), about to lock the DLL\n") ;
        // Keep this DLL in process, so that the C++ callback is present to get invoked
        mexLock() ;        
    }
    
    // Find a free slot
    bool didFindFreeSlot = false ;
    uint64 freeSlotIndex ;
    for (uint64 i=0; i<N_SLOTS; ++i)  {
        if (!IS_SLOT_IN_USE[i])  {
            freeSlotIndex = i ;
            didFindFreeSlot = true ;
            break ;
        }
    }
    if (!didFindFreeSlot)  {
        mexErrMsgIdAndTxt("FileExistenceChecker:noFreeSlots", 
                          "Unable to create the FileExistenceChecker (no free slots)") ;
    }

    // At this point, freeSlotIndex holds the index of a free slot    
    
	// prhs[0]: self (a scalar FileExistenceChecker)
	mxArray* self = (mxArray*)(prhs[0]) ;  // Have to strip the const
    
    // self.Callback
	mxArray *callbackAsMxArrayPointer = mxGetProperty(self, 0, "Callback") ;  // makes a copy
    //mexPrintf("in .start(), callback pointer: 0x%016llx\n", (uint64)(callbackAsMxArrayPointer) ) ;    
    //const char *className = mxGetClassName(callbackAsMxArrayPointer) ;
    //mexPrintf("In .start(), the class of callbackAsMxArrayPointer is %s\n", className) ;
    // need to free className?
    mexMakeArrayPersistent(callbackAsMxArrayPointer);  
      // Need this to hang around after this function exits, so it's available to the hook and callback functions

    // Store the callback in the (global) slot
    CALLBACKS[freeSlotIndex] = callbackAsMxArrayPointer ;
    IS_SLOT_IN_USE[freeSlotIndex] = true ;
    ++N_SLOTS_IN_USE;
    
    // In the timer, store the UID
    mxSetPropertyToUint64Scalar(self, "UID_", (uint64)(freeSlotIndex)) ;
    
    // Zero out a bunch of private fields, to be tidy
    mxSetPropertyToUint64Scalar(self, "ThreadHandle_", (uint64)(0)) ;
    mxSetPropertyToUint64Scalar(self, "ThreadId_", (uint64)(0)) ;
    mxSetPropertyToUint64Scalar(self, "EndChildThreadEventHandle_", (uint64)(0)) ;

    // FileExistenceCheckers start out in the non-running state
    mxSetPropertyToLogicalScalar(self, "IsRunning", false) ;
}

void start(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
	//
	// Read input arguments
	//

    //mexPrintf("At RandomThread::start() point 1, the number is %u\n",(unsigned)(pow(2.0,32.0))) ;
    
	// prhs[0]: self (a scalar FileExistenceChecker)
	mxArray* self = (mxArray*)(prhs[0]) ;  // Have to strip the const
    
	// Check self.IsRunning
    bool isRunning = mxGetLogicalScalarProperty(self, "IsRunning") ;
    if (isRunning)  {
        // If running, nothing more to do
        return ;
    }

    mexPrintf("At RandomThread::start() point 2\n") ;

	// self.FilePath
	mxArray *filePathAsMxArrayPointer = mxGetProperty(self, 0, "FilePath") ;
    char *filePath ;  // this will be allocated on the heap with mxMalloc(), but will be released when mexFunction returns, which is OK, 
                             // because we make a copy in the child thread
    bool didSucceed = mallocedStringFromMxArray(&filePath, filePathAsMxArrayPointer) ;
    if (!didSucceed)  {
        mexErrMsgIdAndTxt("FileExistenceChecker:unableToCopyFilePath", 
                          "Unable to start the FileExistenceChecker (unable to create a C string on the heap from the FilePath)") ;        
    }    
            
	// self.Callback (we actually get a pointer to a copy of this)
    uint64 uid  = mxGetUint64ScalarProperty(self, "UID_") ;
	mxArray *callbackAsMxArrayPointer = CALLBACKS[uid] ;
    
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
    mxSetPropertyToUint64Scalar(self, "EndChildThreadEventHandle_", (uint64)(endChildThreadEventHandle)) ;
    
    // Package up the child thread arguments	
	ChildThreadArguments* childThreadArgumentsPointer = (ChildThreadArguments*)(malloc(sizeof(ChildThreadArguments))) ;  
    childThreadArgumentsPointer->mainThreadId = GetCurrentThreadId() ;
    childThreadArgumentsPointer->endChildThreadEventHandle = endChildThreadEventHandle ;
	childThreadArgumentsPointer->callbackAsMxArrayPointer = callbackAsMxArrayPointer ;
    childThreadArgumentsPointer->filePath = filePath ;
	
    mexPrintf("At RandomThread::start() point 5, about to start child thread with endChildThreadEventHandle = %lld\n", endChildThreadEventHandle) ;
    
    // Spawn the child thread
	HANDLE threadHandle = (HANDLE)(_beginthreadex(NULL, 0, &childThreadProcedure, childThreadArgumentsPointer, 0, NULL)) ;

    mexPrintf("At RandomThread::start() point 6\n") ;
    
    // Store the thread handle in self, so we can signal it to stop later
    mxSetPropertyToUint64Scalar(self, "ThreadHandle_", (uint64)(threadHandle)) ;
    
    mexPrintf("At RandomThread::start() point 7\n") ;
        
    // Get the thread ID, mostly for debugging purposes
    DWORD threadId = GetThreadId(threadHandle) ;
    mxSetPropertyToUint64Scalar(self, "ThreadId_", (uint64)(threadId)) ;
    
    // Set self.IsRunning to true
    mxSetPropertyToLogicalScalar(self, "IsRunning", true) ;
    bool isRunningCheck = mxGetLogicalScalarProperty(self, "IsRunning") ;
    if (isRunningCheck)  {
         mexPrintf("At RandomThread::start() point 9, self.IsRunning = true\n") ;
    }
    else  {
         mexPrintf("At RandomThread::start() point 9, self.IsRunning = false\n") ;
    }
        
    mexPrintf("At RandomThread::start() point 8\n") ;

    // Nothing else to do here
}

void stop(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
	// prhs[0]: self (a scalar FileExistenceChecker)
	mxArray* self = (mxArray*)(prhs[0]) ;  // Have to strip the const
    
	// Check self.IsRunning
	mxArray* isRunningAsMxArrayPointer = mxGetProperty(self, 0, "IsRunning") ;
    double isRunningAsDouble = mxGetScalar(isRunningAsMxArrayPointer) ;
    bool isRunning = bool(isRunningAsDouble) ;
    if (!isRunning)  {
        // If not running, nothing more to do
        return ;
    }
    
    // Get the event handle we'll use to signal the child thread to exit
    HANDLE endChildThreadEventHandle = (HANDLE)(mxGetUint64ScalarProperty(self, "EndChildThreadEventHandle_")) ;

    // Get the thread handle
    HANDLE threadHandle = (HANDLE)(mxGetUint64ScalarProperty(self, "ThreadHandle_")) ;
    
    mexPrintf("In RandomThread::stop(), about to stop child thread with endChildThreadEventHandle = %lld\n", endChildThreadEventHandle) ;    
    
    // Tell the child thread to stop
    bool didThatWork = SetEvent(endChildThreadEventHandle) ;
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

    mexPrintf("In RandomThread::stop(), child thread seems to have stopped.\n") ;        

    // Now close the thread handle, which apparently we have to do b/c we started it with _beginthreadex()
    bool didThatWork2 = CloseHandle(threadHandle) ;  // this returns a bool indicating success/failure, but not sure what I would do if it failed
    if (!didThatWork2)  {
        mexWarnMsgIdAndTxt("FileExistenceChecker:unableToCloseChildThreadHandle", 
                           "Unable to stop the FileExistenceChecker cleanly (CloseHandle failed)") ;  
    }    

    mexPrintf("In RandomThread::stop(), successfully closed child thread handle.\n") ;        
    
    // Zero the thread handle
    mxSetPropertyToUint64Scalar(self, "ThreadHandle_", (uint64)(0)) ;
    mxSetPropertyToUint64Scalar(self, "ThreadId_", (uint64)(0)) ;  // zero this too

    // Release the event handle
    bool didThatWork3 = CloseHandle(endChildThreadEventHandle) ;
    if (!didThatWork)  {
        // What to do here?  Try again?  Proceed like all is well?
        mexErrMsgIdAndTxt("FileExistenceChecker:unableToReleaseEvent", 
                          "Unable to stop the FileExistenceChecker cleanly, may be in a weird state and/or have leaked resources (CloseHandle failed)") ;
    }

    // Zero the event handle
    mxSetPropertyToUint64Scalar(self, "EndChildThreadEventHandle_", (uint64)(0)) ;
    
    // Finally, set IsRunning to false
    mxSetPropertyToLogicalScalar(self, "IsRunning", false) ;
}

void finalize(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {    
    // This should be called by the FileExistenceChecker delete() method.
    
    mexPrintf("In RandomThread::finalize()\n") ;        
    
	// prhs[0]: self (a scalar FileExistenceChecker)
	mxArray* self = (mxArray*)(prhs[0]) ;  // Have to strip the const
    
    // Get the timer UID/slot-index
    uint64 slotIndex = mxGetUint64ScalarProperty(self, "UID_") ;
    
    // Mark the slot as free, decrement in-use counter
    IS_SLOT_IN_USE[slotIndex] = false ;
    --N_SLOTS_IN_USE;

    // Free the callback storage
    mxArray* callbackAsMxArrayPointer = CALLBACKS[slotIndex] ;
    mxDestroyArray(callbackAsMxArrayPointer) ;
    CALLBACKS[slotIndex] = (mxArray*)(0) ;  // for my protection
    
    // If this was the last timer standing, unregister the hook and release it
    if (N_SLOTS_IN_USE==0)  {
        mexPrintf("In RandomThread::finalize(), about to unregister the hook and unlock the DLL\n") ;
        
        // Unregister the hook function
        bool didThatWork = UnhookWindowsHookEx(HOOK_HANDLE) ;
        if (!didThatWork)  {
            // What to do here?  Try again?  Proceed like all is well?
            mexWarnMsgIdAndTxt("FileExistenceChecker:unableToRemoveHook", 
                               "Unable to remove the Windows hook, DLL may be in a weird state and/or have leaked resources (UnhookWindowsHookEx failed)") ;
        }

        // Zero the hook handle
        HOOK_HANDLE = NULL ;

        // Allow this DLL to be cleared, if needed or requested
        mexUnlock() ;        
    }
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
    // Dispatch on the method name
    if (nrhs<2)  {
        mexErrMsgIdAndTxt("FileExistenceChecker:callMexMethod_:tooFewArguments",
                          "FileExistenceChecker::callMexMethod_() needs at least two arguments") ;
    }
    
	const mxArray* methodNameAsMxArray = (mxArray*)(prhs[1]) ;
    char* methodName = mxArrayToString(methodNameAsMxArray) ;  // Do I need to free this?
    if ( strcmp(methodName,"initialize")==0 )  {
        initialize(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(methodName,"start")==0 )  {
        start(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(methodName,"stop")==0 )  {
        stop(nlhs, plhs, nrhs, prhs) ;
    }
    else if ( strcmp(methodName,"finalize")==0 )  {
        finalize(nlhs, plhs, nrhs, prhs) ;
    }
    else  {
        // Doesn't match anything, so error
        mexErrMsgIdAndTxt("FileExistenceChecker:callMexMethod_:noSuchMethod",
                          "FileExistenceChecker::callMexMethod_() doesn't recognize that method name") ;
    }
}
