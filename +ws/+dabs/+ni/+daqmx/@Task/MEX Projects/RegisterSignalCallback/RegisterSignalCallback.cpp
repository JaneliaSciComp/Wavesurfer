#include "RegisterXXXCallback.h"

//Matlab signature
//status = RegisterSignalCallback(taskObj,signalID,registerTF)
//registerTF: (OPTIONAL, logical). If 'true', register the signalEvent on the taskObj. 
//  If 'false', unregister that event. Default is 'true'.
// zzz what is status

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (!mexIsLocked())	{
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

	//Parse general input arguments
	bool registerTF;
	TaskHandle taskID;
	parseGeneralInputs(nrhs, prhs, &registerTF, &taskID);

	//Handle signalEvent specific arguments
	const mxArray *taskObj = prhs[0];
	int32 signalID = (int32)mxGetScalar(mxGetProperty(taskObj,0,"signalIDHidden"));

	//Determine whether to register
	bool isRegistered = CBDStoreIsRegistered(taskID);
	int32 status = -1;
	if (registerTF)	{
		if (isRegistered) {
			mexErrMsgTxt("TaskID/Event combo already registered.");			
		}

		int32 (*funcPtr)(TaskHandle, int32, void*) = callbackWrapper;
		CallbackData *cbd = CBDCreate(taskObj, SIGNAL_EVENT, "signalEventCallbacks", NULL, NULL);
		status = DAQmxRegisterSignalEvent(taskID, signalID, DAQmx_Val_SynchronousEventCallbacks, funcPtr, cbd);
		if (status==0) {
			// Successfully registered with DAQmx
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
		status = DAQmxRegisterSignalEvent(taskID, signalID, DAQmx_Val_SynchronousEventCallbacks, 0, 0);
	}

	nlhs = 1;
	plhs[0] = mxCreateDoubleScalar(status);
}
