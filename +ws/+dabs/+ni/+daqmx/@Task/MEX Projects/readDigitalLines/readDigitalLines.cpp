//#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx.h"
#include "string.h"

// Helper functions
void handleDAQmxError(int32 status, const char *functionName) {
	//Display DAQmx error string
	int32 errorStringBufferSize = DAQmxGetErrorString(status, NULL, 0) ;  // Gets size of buffer needed
	char* errorString = (char*) mxCalloc(errorStringBufferSize, sizeof(char)) ;
	DAQmxGetErrorString(status,errorString,errorStringBufferSize);
    int32 finalErrorStringBufferSize = errorStringBufferSize+100 ;
	char* finalErrorString = (char*) mxCalloc(finalErrorStringBufferSize, sizeof(char)) ;
	sprintf_s(finalErrorString, finalErrorStringBufferSize, "DAQmx Error (%d) encountered in %s:\n %s\n", status, functionName, errorString);
	mexErrMsgTxt(finalErrorString);
}

// Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])  {
	int32 status;  // used many places to see if DAQmx calls wre successful

    // prhs[0]: task
    // prhs[1]: nScansRequested
    // prhs[2]: timeout

    // prhs[0]: task
	TaskHandle taskID, *taskIDPtr;
	taskIDPtr = (TaskHandle*)mxGetData(mxGetProperty(prhs[0],0, "taskID"));
	taskID = *taskIDPtr;

    // prhs[1]: nScansRequested
	int nScansRequested;
	if ((nrhs < 2) || mxIsEmpty(prhs[1]) || mxIsInf(mxGetScalar(prhs[1])))  {
        nScansRequested = DAQmx_Val_Auto ;  
          // This may not work for non-buffered channels, but I think I'm OK with that.  
          // Also, I prefer when these mex functions do the minimum amount possible outside of the call to the
          // main DAQmx function (here, DAQmxReadDigitalLines()).
        /*
	    // Determine if this is a buffered read operation
	    uInt32 sizeOfInputBuffer;
	    status = DAQmxGetBufInputBufSize(taskID, &sizeOfInputBuffer);
	    if (status)
		    handleDAQmxError(status, "DAQmxGetBufInputBufSize");
        const bool isTaskBuffered = (sizeOfInputBuffer>0) ;
        // If a non-buffered task, always acquire one sample.  Otherwise, acquire all available
		if (isTaskBuffered)
			nScansRequested = DAQmx_Val_Auto ;
		else
			nScansRequested = 1 ;
        */
	}
	else  {
		nScansRequested = (int) mxGetScalar(prhs[1]);
    }

    // prhs[2]: timeout
	double timeout ;
	if ((nrhs < 3) || mxIsEmpty(prhs[2]) || mxIsInf(mxGetScalar(prhs[2])))
		timeout = DAQmx_Val_WaitInfinitely;
	else
		timeout = mxGetScalar(prhs[3]);

	// Determine # of channels
	uInt32 nChannels ; 
	status = DAQmxGetReadNumChans(taskID, &nChannels) ;  // Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
	if (status)
		handleDAQmxError(status, "DAQmxGetReadNumChans");  // this terminates the mex function
	
    // Determine number of bytes per channel
    // Digital channels can have multiple lines per channel.  This gives the maximum number of lines per channel, across all channels in the task.
	uInt32 nLinesPerChannel ; 
	status = DAQmxGetReadDigitalLinesBytesPerChan(taskID, &nLinesPerChannel) ;  // Each line takes up a byte, so this is the maximum number of lines per channel
	if (status)
		handleDAQmxError(status, "DAQmxGetReadDigitalLinesBytesPerChan");  // this terminates the mex function

    // Determine how many scans to *attempt* to read.
    // We need to know this before calling DAQmxReadDigitalLines() so that we can allocate storage for that many scans.
    uInt32 nScansToAttemptToRead ;
    if (nScansRequested == DAQmx_Val_Auto)  { // this means the user wants as many scans as are available
		status = DAQmxGetReadAvailSampPerChan(taskID, &nScansToAttemptToRead);
		if (status)
			handleDAQmxError(status, "DAQmxGetReadAvailSampPerChan");  // this terminates the mex function
    }
    else {
        nScansToAttemptToRead = nScansRequested ;
    }
	
	// Allocate a buffer to store the data
	mxArray *dataBuffer;
    uInt32 nLines = nChannels*nLinesPerChannel ;
	dataBuffer = mxCreateLogicalMatrix(nScansToAttemptToRead, nLines) ;
    uInt32 dataBufferSizeInSamples = nScansToAttemptToRead*nLines ;
	void *dataBufferPtr = mxGetData(dataBuffer) ;

	// Read data
	int32 nScansRead ;
	int32 nBytesPerScan ;

	// The DAQmx reading functions complain if you call them when there's no more data to read, even if you ask for zero scans.
	// So we don't attempt a read if nScansToAttemptToRead is zero.
	if (nScansToAttemptToRead>0)  {
        status = DAQmxReadDigitalLines(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt8*) dataBufferPtr, dataBufferSizeInSamples, &nScansRead, &nBytesPerScan, NULL);
        if (status)
	        handleDAQmxError(status, "DAQmxReadDigitalLines") ;
	}
	else  {
		nScansRead = 0 ;
        nBytesPerScan = 0 ;
		status = 0 ;
	}

	//mexPrintf("Successfully read %d scans of data\n", nScansRead);		

    // Assign to plhs[0] no matter how many LHS args there are, so ans gets assigned
    plhs[0] = dataBuffer;

    // Assign to plhs[1], if requested
    if (nlhs>=2)  {  // Return number of samples actually read
		plhs[1] = mxCreateDoubleScalar(0);	
		double *nScansReadOutput = mxGetPr(plhs[1]);
		*nScansReadOutput = (double)nScansRead;
    }

    // Assign to plhs[2], if requested
    if (nlhs>=3)  {  // Return max number of bytes per scan
		plhs[2] = mxCreateDoubleScalar(0);	
		double *nBytesPerScanOutput = mxGetPr(plhs[2]) ;
		*nBytesPerScanOutput = (double)nBytesPerScan ;
    }

}
