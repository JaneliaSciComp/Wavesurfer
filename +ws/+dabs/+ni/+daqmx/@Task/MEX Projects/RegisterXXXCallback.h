#pragma once

#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx.h"
#include <map>

#define DEBUG_MEX 0

#define MAXNUMCALLBACKS 10
#define MAXCALLBACKNAMELENGTH 256

typedef enum {
	DONE_EVENT = 0,
	SIGNAL_EVENT,
	EVERY_N_EVENT,
	NUMCALLBACKTYPES
} CallbackTypeEnum;

extern const char *CallbackTypeStrings[NUMCALLBACKTYPES];

typedef struct {
	mxArray *taskObjHandle; //Handle to Matlab object
	TaskHandle taskHandle; //The handle provided by underlying API; serves as key value for search/sort
	mxArray *callbackFuncHandles[MAXNUMCALLBACKS]; //Array of function handles, which will be evaluated in Matlab in specified order when event occurs
	size_t numCallbacks; //Length of callbackFuncHandles array
	const char *callbackType; //String identifying callback type
	mxArray *eventData;
	void *callbackTypeData; //Optional data, related to particular callbackType	
} CallbackData;

// No throw
extern "C" bool CBDStoreIsRegistered(TaskHandle taskID);

// Caller gives ownership of cbd to CBDStore. 
// No throw
extern "C" void CBDStoreAddCallbackData(TaskHandle taskID, CallbackData *cbd);

// Returns true if (taskID,type) was previously registered and a CBD was erased; false otherwise.
// No throw
extern "C" bool CBDStoreRmCallbackData(TaskHandle taskID);

// Destroys/erases all CBDs in CBDStore.
// No throw
extern "C" void CBDStoreCleanupAll(void);

// No throw
extern "C" void CBDStoreDebugDump(void);

// Creates a CBD. Caller responsible for returned memory (delete with CBDDestroy).
// Pass NULL for eventData to get default eventData (empty struct). The returned CBD has
// ownership of callbackTypeData (freed with mxFree) and eventData (if provided). 
// callbackTypeData, eventData should be mex-persistentified already.
// Throws. This can throw a mexErrMsgTxt (and leak some mem) in very rare situations.
CallbackData * CBDCreate(const mxArray *taskObj,CallbackTypeEnum typeenum,
						 const char *callbackFuncProp,mxArray *eventData, void *callbackTypeData);

// No throw
void CBDDestroy(CallbackData *cbd);

// No throw
void parseGeneralInputs(int nrhs, const mxArray *prhs[], bool *registerTF, TaskHandle *taskID);

// No throw
void cleanUp(void);

// No throw
int32 CVICALLBACK callbackWrapper(TaskHandle taskHandle, int32 eventInfo, void *callbackData);
