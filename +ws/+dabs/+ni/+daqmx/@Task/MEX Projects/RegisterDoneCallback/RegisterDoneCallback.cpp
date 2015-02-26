#include "RegisterXXXCallback.h"

//Matlab signature
//status = RegisterDoneCallback(taskObj,registerTF)
// registerTF: (OPTIONAL) Logical value indicating if 'true', to register the Done Event and, if 'false', to unregister the Done Event. If empty/omitted, value 'true' is assumed.
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (!mexIsLocked()) {
		mexLock();
		mexAtExit(cleanUp);
	}

#if DEBUG_MEX
	if (nrhs==3) {
		CBDStoreDebugDump();
		nlhs = 0;
		return;
	}
#endif

	//Parse input arguments to determine whether registration or unregistration is specified
	bool registerTF;
	TaskHandle taskID;
	parseGeneralInputs(nrhs, prhs, &registerTF, &taskID);
	bool isRegistered = CBDStoreIsRegistered(taskID);

	int32 status = -1;
	if (registerTF) {
		if (isRegistered) {
			mexErrMsgTxt("TaskID/Event combo already registered.");
		}

		const mxArray *taskObj = prhs[0];
		int32 (*funcPtr)(TaskHandle, int32, void*) = callbackWrapper;
		CallbackData *cbd = CBDCreate(taskObj,DONE_EVENT,"doneEventCallbacks",NULL,NULL);

		status = DAQmxRegisterDoneEvent(taskID, DAQmx_Val_SynchronousEventCallbacks, funcPtr, cbd);
		if (status==0) {
			//success
#if DEBUG_MEX
			mexPrintf("success");
#endif
			CBDStoreAddCallbackData(taskID,cbd);
		} else {
#if DEBUG_MEX
			mexPrintf("failure");
#endif
			CBDDestroy(cbd);
		}
	} else { // unregister
		CBDStoreRmCallbackData(taskID);
		status = DAQmxRegisterDoneEvent(taskID, DAQmx_Val_SynchronousEventCallbacks, 0, 0);
	}

	nlhs = 1;
	plhs[0] = mxCreateDoubleScalar(status);
}