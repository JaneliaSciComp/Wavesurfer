#include <cstring>
#include "mex.h"
#include "NIDAQmx.h"

#ifdef _WIN64
#define TASKHANDLE_MXCLASS mxUINT64_CLASS
#else
#define TASKHANDLE_MXCLASS mxUINT32_CLASS
#endif

//Helper functions
void handleDAQmxError(int32 status, const char *functionName)
{
	//Display DAQmx error string
	int32 errorStringSize = DAQmxGetErrorString(status,NULL,0); //Gets size of buffer
	char *errorString = (char *)mxCalloc(errorStringSize,sizeof(char));
	char *finalErrorString = (char*) mxCalloc(errorStringSize+100,sizeof(char));
	DAQmxGetErrorString(status,errorString,errorStringSize);
	sprintf(finalErrorString, "DAQmx Error (%d) encountered in %s:\n %s\n", status,functionName,errorString);
	mxFree(errorString);
	char *errorIdString = (char *)mxCalloc(256+strlen(functionName),sizeof(char));
	sprintf(errorIdString, "dabs:ni:daqmx:%s", functionName) ;
	mexErrMsgIdAndTxt(errorIdString,finalErrorString);
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	//
	// Read input arguments
	//

	// prhs[0]: task
	// Get the task handle
	mxArray *mxTaskID = mxGetProperty(prhs[0],0,"taskID");
	mxClassID clsID = mxGetClassID(mxTaskID);
	if (clsID!=TASKHANDLE_MXCLASS) {
		mexErrMsgIdAndTxt("dabs:ni:daqmx:notATask",
			              "First argument must be a DABS Task object");
	}
	TaskHandle *taskIDPtr = (TaskHandle*)mxGetData(mxTaskID);
	TaskHandle taskID = *taskIDPtr;

	// Call the DAQmx function
	int32 status;
	uInt32 nAvailableSamplesPerChannel;
	status = DAQmxGetReadAvailSampPerChan(taskID,&nAvailableSamplesPerChannel);
	if (status) {
		handleDAQmxError(status, mexFunctionName());
	}

	// Return the number of samples available
	plhs[0] = mxCreateDoubleScalar((double)nAvailableSamplesPerChannel);	// even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
}

