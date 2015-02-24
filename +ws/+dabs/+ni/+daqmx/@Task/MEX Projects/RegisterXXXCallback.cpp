// RegisterXXXCallbackShared.cpp : Shared functions/definitions among registerXXXCallback() methods

#include "RegisterXXXCallback.h"

//////////////////
// CallbackData //
//////////////////

const char *CallbackTypeStrings[NUMCALLBACKTYPES] = {"doneEvent","signalEvent","everyNEvent"};

static void CBDDebug(CallbackData *cbd)
{
	mexPrintf("CBDDebug. cbd: %p.\n", cbd);
	if (cbd) {
		mexPrintf("taskObjHandle taskHandle numcallbacks callbacktype eventdata typedata %p %d %d %s %p %p\n",
			cbd->taskObjHandle, cbd->taskHandle, cbd->numCallbacks, cbd->callbackType, 
			cbd->eventData, cbd->callbackTypeData);
	}
}

CallbackData * CBDCreate(const mxArray *taskObj, 
						 CallbackTypeEnum callbackTypeEnum,
						 const char *callbackFuncProp,
						 mxArray *eventData,
						 void *callbackTypeData)
{
	CallbackData *cbd = (CallbackData*)mxCalloc(1,sizeof(CallbackData));
	mexMakeMemoryPersistent(cbd);

	//Pack callbackData structure
	cbd->taskObjHandle = mxDuplicateArray(taskObj);
	mexMakeArrayPersistent(cbd->taskObjHandle);

	mxArray *mxTaskID = mxGetProperty(taskObj,0,"taskID");
	TaskHandle *taskIDPtr = (TaskHandle*)mxGetData(mxTaskID);
	cbd->taskHandle = *taskIDPtr;
	mxDestroyArray(mxTaskID);

	mxArray *callbackFuncs = mxGetProperty(taskObj,0,callbackFuncProp);
	size_t numCallbacks = mxGetNumberOfElements(callbackFuncs);
	if (numCallbacks > MAXNUMCALLBACKS) {
		mexErrMsgTxt("Exceeded the maximum allowed number of callback functions."); /// leak a bunch of memory, no biggie (see doc for fcn)
	}
	for (size_t i=0;i<numCallbacks;i++) {
		cbd->callbackFuncHandles[i] = mxDuplicateArray(mxGetCell(callbackFuncs,i));
		mexMakeArrayPersistent(cbd->callbackFuncHandles[i]);
	}
	mxDestroyArray(callbackFuncs);
	for (size_t i=numCallbacks;i<MAXNUMCALLBACKS;++i) {
		cbd->callbackFuncHandles[i] = NULL;
	}
	cbd->numCallbacks = numCallbacks;
	
	cbd->callbackType = CallbackTypeStrings[callbackTypeEnum];

	if (eventData==NULL) {
		// use default empty event array
		mxArray *eventArray = mxCreateStructMatrix(0, 0, 0, 0);
		mexMakeArrayPersistent(eventArray);
		cbd->eventData = eventArray;
	} else {
		cbd->eventData = eventData; 
	}
	cbd->callbackTypeData = callbackTypeData;

#if DEBUG_MEX
	mexPrintf("At end of CBDCreate.\n");
	CBDDebug(cbd);
#endif

	return cbd;
}

void CBDDestroy(CallbackData *cbd) 
{
#if DEBUG_MEX
	mexPrintf("At beginning of CBDDestroy.\n");
	CBDDebug(cbd);
#endif
	if (cbd!=NULL) {
		if (cbd->taskObjHandle!=NULL) {
			mxDestroyArray(cbd->taskObjHandle);
			cbd->taskObjHandle = NULL;
		}
		for (int i=0;i<MAXNUMCALLBACKS;++i) {
			if (cbd->callbackFuncHandles[i]!=NULL) {
				mxDestroyArray(cbd->callbackFuncHandles[i]);
				cbd->callbackFuncHandles[i]=NULL;
			}
		}
		if (cbd->eventData!=NULL) {
			mxDestroyArray(cbd->eventData);
			cbd->eventData = NULL;
		}
		if (cbd->callbackTypeData!=NULL) {
			mxFree(cbd->callbackTypeData);
			cbd->callbackTypeData = NULL;
		}
		mxFree(cbd);
	}
}

//////////////////////
// END CallbackData //
//////////////////////


////////////////////////
// Registration store //
////////////////////////

static std::map<TaskHandle,CallbackData*> CBDStore;
typedef std::map<TaskHandle,CallbackData*>::iterator CBDStoreIterator;
typedef std::map<TaskHandle,CallbackData*>::const_iterator ConstCBDStoreIterator;

bool CBDStoreIsRegistered(TaskHandle taskID)
{
	return CBDStore.find(taskID)!=CBDStore.end();
}
 
void CBDStoreAddCallbackData(TaskHandle taskID, CallbackData *cbd)
{
	assert(taskID!=0);
	assert(cbd!=NULL);
	assert(!CBDStoreIsRegistered(taskID));
	CBDStore[taskID] = cbd;
#if DEBUG_MEX
	mexPrintf("CBDStore add\n");
	CBDStoreDebugDump();
#endif
}

bool CBDStoreRmCallbackData(TaskHandle taskID)
{
#if DEBUG_MEX
	mexPrintf("CBDStore remove\n");
	CBDStoreDebugDump();
#endif
	CBDStoreIterator it = CBDStore.find(taskID);
	if (it!=CBDStore.end()) {
		CallbackData *cbd = it->second;
		assert(cbd);
		CBDDestroy(cbd);
		CBDStore.erase(it);
		return true;
	}
	return false;
}

void CBDStoreCleanupAll(void)
{
#if DEBUG_MEX
	mexPrintf("cleanup all\n");
	CBDStoreDebugDump();
#endif
	CBDStoreIterator it, itend;
	for (it=CBDStore.begin(),itend=CBDStore.end();it!=itend;++it) {
		CallbackData *cbd = it->second;
		assert(cbd);
		CBDDestroy(cbd);
	}
	CBDStore.clear();
}

void CBDStoreDebugDump(void)
{
	mexPrintf("CBDStore address: %p. size: %d\n", &CBDStore, CBDStore.size());
	ConstCBDStoreIterator it, itend;
	for (it=CBDStore.begin(),itend=CBDStore.end();it!=itend;++it) {
		CBDDebug(it->second);
	}
}

////////////////////////////
// END Registration store //
////////////////////////////

//MEX Exit function
void cleanUp(void)
{
	CBDStoreCleanupAll();
}

void parseGeneralInputs(int nrhs, const mxArray *prhs[], bool *registerTF, TaskHandle *taskID) 
{
	assert(nrhs>=1);
	const mxArray *task = prhs[0];
	TaskHandle *taskIDPtr;

	//Get TaskHandle
	taskIDPtr = (TaskHandle*)mxGetData(mxGetProperty(prhs[0],0, "taskID"));
	*taskID = (TaskHandle)*taskIDPtr;

	//Process argument 2 - registerTF
	if ((nrhs < 2) || mxIsEmpty(prhs[1])) {
		*registerTF =  true;
	} else {
		mxLogical *registerTFTemp = mxGetLogicals(prhs[1]);
		*registerTF = (bool) *registerTFTemp;
	}
}

//Variable definitions
//char *initializedCallbackTypes[]; //Array of strings identifying which callback types have been initialized

int32 CVICALLBACK callbackWrapper(TaskHandle taskHandle, int32 eventInfo, void *callbackData)
{
	CallbackData *cbData = (CallbackData*)callbackData;

	mxArray *rhs[3];
	rhs[1] = cbData->taskObjHandle;
	rhs[2] = cbData->eventData;
	
#if DEBUG_MEX
	mexPrintf("in CBWrap\n");
#endif

	int32 retval = 0;
	size_t cachedNCB = cbData->numCallbacks; // veej wants deletion of a task object during a DONE callback to work
	const char *cachedCBT = cbData->callbackType; 
	for (size_t i=0;i<cachedNCB;i++){
#if DEBUG_MEX
	mexPrintf("in CBWrap, calling %d\n",i);
#endif
		//mException = mexCallMATLABWithTrap(0,NULL,0,0,cbData->callbackFuncNames[i]); //TODO -- pass arguments!
		rhs[0] = cbData->callbackFuncHandles[i];
		mxArray *mException = mexCallMATLABWithTrap(0,NULL,3,rhs,"feval"); //TODO -- pass arguments!
		if (!mException) {
			continue;
		} else {
			char *errorString = (char*)mxCalloc(256,sizeof(char));
			mxGetString(mxGetProperty(mException,0,"message"),errorString,MAXCALLBACKNAMELENGTH);
			mexPrintf("ERROR in %s callback of Task object: %s\n",cachedCBT,errorString);
			mxFree(errorString);
			retval = 1;
			break;
		}
	}

	return retval;
}
