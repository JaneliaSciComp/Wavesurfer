#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx_mod.h"

//%readDigitalData - Read digital data from a digital input task
//%
//%   [outputData, nScansRead] = readDigitalData(task, nBits, nScansWanted, timeout) 
//%   
//%     task: the handle of the ws.dabs.ni.daqmx.Task object
//%
//%     outputFormat: The type of output data desired.  Should be 'uint8',
//%                   'uint16', 'uint32'.  This determines which of the 
//%                   DAQmxReadDigitalU<n>() functions is called to read the
//%                   data.  Required.
//%
//%     nScansWanted: The number of scans (time points) of data desired.  If
//%                   omitted, empty, or +inf, all available scans are returned.
//%
//%     timeout: The maximum time to wait for nScansWanted scans to happen.
//%              If empty, omitted, or inf, will wait indefinitely.
//%
//%
//%
//%   Outputs:
//%
//%     outputData: The data, an unsigned int column vector of the requested
//%                 type.  Each element corresponds to a single scan, with
//%                 the lines packed into the bits of the unsigned int.
//%
//%     nScansRead: The number of scans actually read.  This may be smaller
//%                 than nScansWanted.

//Helper functions
void handleDAQmxError(int32 status, const char *functionName)
    {
	int32 errorStringSize;
	char *errorString;

	char *finalErrorString;

	//Display DAQmx error string
	errorStringSize = DAQmxGetErrorString(status,NULL,0); //Gets size of buffer
	errorString = (char *)mxCalloc(errorStringSize,sizeof(char));
	finalErrorString = (char*) mxCalloc(errorStringSize+100,sizeof(char));

	DAQmxGetErrorString(status,errorString,errorStringSize);

	sprintf(finalErrorString, "DAQmx Error (%d) encountered in %s:\n %s\n", status, functionName, errorString);
	mexErrMsgTxt(finalErrorString);
    }

//Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
    {
	int32 status;  // used many places to see if DAQmx calls wre successful

    // prhs[0]: task
    // prhs[1]: outputFormat
    // prhs[2]: nScansRequested
    // prhs[3]: timeout

    // prhs[0]: task
	TaskHandle taskID, *taskIDPtr;
	taskIDPtr = (TaskHandle*)mxGetData(mxGetProperty(prhs[0],0, "taskID"));
	taskID = *taskIDPtr;

    // prhs[1]: outputFormat
	mxClassID outputDataClass;
    //bool isMaxLinesPerChannelKnown = false ;
	if ( (nrhs < 2) || mxIsEmpty(prhs[1]) )
	    {
		// Have to provide this
    	mexErrMsgTxt("The 'outputFormat' argument is required.  Should be 'uint8', 'uint16', or 'uint32'.");
	    }
	else
	    {
    	char outputFormat[10] ;
        mxGetString(prhs[1], outputFormat, 10);		

		if (_strcmpi(outputFormat,"uint8") == 0)
			outputDataClass = mxUINT8_CLASS;
		else if (_strcmpi(outputFormat,"uint16") == 0)
			outputDataClass = mxUINT16_CLASS;
		else if (_strcmpi(outputFormat,"uint32") == 0)
			outputDataClass = mxUINT32_CLASS;
		else
			mexErrMsgTxt("The specified 'outputFormat' value (case-sensitive) is not recognized or not supported.  Should be 'uint8', 'uint16', or 'uint32'.");
	    }

    // prhs[2]: nScansRequested
	int nScansRequested;
	if ((nrhs < 3) || mxIsEmpty(prhs[2]) || mxIsInf(mxGetScalar(prhs[2])))
	    {
	    // Determine if this is a buffered read operation
	    uInt32 sizeOfInputBuffer;
	    status = DAQmxGetBufInputBufSize(taskID, &sizeOfInputBuffer);
	    if (status)
            {
		    handleDAQmxError(status, "DAQmxGetBufInputBufSize");
            }
        const bool isTaskBuffered = (sizeOfInputBuffer>0) ;
        // If a non-buffered task, always acquire one sample.  Otherwise, acquire all available
		if (!isTaskBuffered)
			nScansRequested = 1;
		else
			nScansRequested = DAQmx_Val_Auto;
	    }
	else
        {
		nScansRequested = (int) mxGetScalar(prhs[2]);
        }
	

    // prhs[3]: timeout
	double timeout ;
	if ((nrhs < 4) || mxIsEmpty(prhs[3]) || mxIsInf(mxGetScalar(prhs[3])))
		timeout = DAQmx_Val_WaitInfinitely;
	else
		timeout = mxGetScalar(prhs[3]);

	// Determine # of channels
	uInt32 nChannels ; 
	status = DAQmxGetReadNumChans(taskID, &nChannels);  // Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
	if (status)
		handleDAQmxError(status, "DAQmxGetReadNumChans");  // this terminates the mex function
	
    // Determine how many scans to *attempt* to read
    uInt32 nScansToAttemptToRead ;
	if (nScansRequested == DAQmx_Val_Auto)  // this means the user wants as many scans as are available
    	{
		status = DAQmxGetReadAvailSampPerChan(taskID, &nScansToAttemptToRead);
		if (status)
			handleDAQmxError(status, "DAQmxGetReadAvailSampPerChan");  // this terminates the mex function
	    }
    else
        {
        nScansToAttemptToRead = nScansRequested ;
        }
	
	// Allocate a buffer to store the data
	mxArray *dataBuffer;
	dataBuffer = mxCreateNumericMatrix(nScansToAttemptToRead, nChannels, outputDataClass, mxREAL) ;
    uInt32 dataBufferSizeInSamples = nScansToAttemptToRead*nChannels ;
	void *dataBufferPtr = mxGetData(dataBuffer);

	// Read data
	int32 nScansRead;
	int32 numBytesPerScan;

	// The DAQmx reading functions complain if you call them when there's no more data to read, even if you ask for zero scans.
	// So we don't attempt a read if nScansToAttemptToRead is zero.
	if (nScansToAttemptToRead>0)  
        {
		switch (outputDataClass)
		    {
		    case mxUINT8_CLASS:
			    status = DAQmxReadDigitalU8(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt8*) dataBufferPtr, dataBufferSizeInSamples, &nScansRead, NULL);
			    break;
		    case mxUINT16_CLASS:
			    status = DAQmxReadDigitalU16(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt16*) dataBufferPtr, dataBufferSizeInSamples, &nScansRead, NULL);
			    break;
		    case mxUINT32_CLASS:
			    status = DAQmxReadDigitalU32(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt32*) dataBufferPtr, dataBufferSizeInSamples, &nScansRead, NULL);
			    break;
		    default:
			    mexErrMsgTxt("Unknown output data class");
		    }
	    }
	else  
        {
		nScansRead=0;
		status=0;
	    }

    // Check for valid return
    if (status)
		handleDAQmxError(status, mexFunctionName());

	//mexPrintf("Successfully read %d scans of data\n", nScansRead);		

    // Assign to plhs[0] no matter how many LHS args there are, so ans gets assigned
    plhs[0] = dataBuffer;

    // Assign to plhs[1], if requested
	if (nlhs>=2)  // Return number of samples actually read
    	{
		plhs[1] = mxCreateDoubleScalar(0);	
		double *nScansReadOutput = mxGetPr(plhs[1]);
		*nScansReadOutput = (double)nScansRead;
	    }

    }

