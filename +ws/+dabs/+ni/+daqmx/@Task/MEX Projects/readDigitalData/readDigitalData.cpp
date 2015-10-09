// readDigitalData.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx_mod.h"

//#define MAXVARNAMESIZE 64


//% General method for reading digital data from a Task containing one or more digital input Channels
//%% function [outputData, sampsPerChanRead] = readDigitalData(task, nScansRequested, outputFormat, timeout, outputVarSizeOrName)
//%	numSampsPerChan: <OPTIONAL - Default: 1/Inf> Specifies (maximum) number of samples per channel to read. If 'inf' or < 0, then all available samples are read, up to the size of the output array  
//%                       If omitted/empty, value of 'Inf'/1 is used for buffered/unbuffered read operations, respectively.
//%           
//%	outputFormat: <OPTIONAL - one of {'logical' 'double' 'uint8' 'uint16' 'uint32'}> Data will be output as specified type, if possible. 
//%               If omitted/empty, data type of output will be determined automatically:
//%                   If read operation is non-buffered and Channels in Task are 'line-based', then double type will be used.
//%                   Otherwise, the smallest allowable choice of uint8/16/32 will be used
//%               If outputFormat=uint8/16/32, and the following restrictions should be followed:
//%                   If Channel in Task are 'port-based', the data type specified must contain as many bits as the largest port in the Task.
//%                   If Channel in Task are 'line-based', the data type specified must contain as many bits as the line in Task belonging to the largest port.
//%                   If Task contains multiple Channels, then the largest data type required by any Channel must be specified (and used for all Channels).
//%   timeout: <OPTIONAL - Default: Inf> Time, in seconds, to wait for function to complete read. If omitted/empty, value of 'Inf' is used. If 'Inf' or < 0, then function will wait indefinitely.
//%	outputVarSizeOrName: <OPTIONAL> Size in samples of output variable to create (to be returned as outputData argument). 
//%                                   If empty/omitted, the output array size is determined automatically. 
//%                                   Alternatively, this may specify name of preallocated MATLAB variable into which to store read data.                                    
//%
//%   outputData: Array of output data with samples arranged in rows and channels in columns. This value is not output if outputVarOrSize is a string specifying a preallocated output variable.
//%               For outputFormat=logical/double, samples for each line are output as separate values, so number of rows will equal (# samples) x (# lines/Channel)
//%                   If multiple Channels are present, (# lines/Channel) value corresponds to Channel with largest # lines.
//%               For outputFormat=uint8/16/32, one value is supplied for each sample, i.e. the number of rows equals (# samples)
//%               NOTE: If Channels are 'line-based' and uint8/16/32 type is used, then data will be arranged in uint8/16/32 value according to the bit/line number 
//%                   (e.g. bit 7 for line 7, even if line 7 is only line in Channel), and NOT by the order/number of lines in the Channel. 
//%                   Bits in the output value corresponding to lines not included in Channel are meaningless.                       
//%   sampsPerChanRead: Number of samples actually read. This may be smaller than that specified/implied by outputVarOrSize.
//%
//%% NOTES
//%   The 'fillMode' parameter of DAQmx API functions is not supported -- data is always grouped by Channel (DAQmx_Val_GroupByChannel).
//%   This corresponds to Matlab matrix ordering where each Channel corresponds to one column. 
//%
//%   If outputFormat is 'logical'/'double', then DAQmxReadDigitalLines function in DAQmx API is used
//%   If outputFormat is 'uint8'/'uint16'/'uint32', then DAQmxReadDigitalU8/U16/U32 functions in DAQmx API are used.
//%
//%   At moment, the option to specify the name of a preallocated MATLAB variable, via the outputVarSizeOrName argument, is not supported.



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
    // prhs[1]: nScansRequested
    // prhs[2]: outputFormat
    // prhs[3]: timeout

    // prhs[0]: task
	TaskHandle taskID, *taskIDPtr;
	taskIDPtr = (TaskHandle*)mxGetData(mxGetProperty(prhs[0],0, "taskID"));
	taskID = *taskIDPtr;

	// Determine if this is a buffered read operation
	uInt32 sizeOfInputBuffer;
	status = DAQmxGetBufInputBufSize(taskID, &sizeOfInputBuffer);
	if (status)
        {
		handleDAQmxError(status, "DAQmxGetBufInputBufSize");
        }
    const bool isTaskBuffered = (sizeOfInputBuffer>0) ;

    // prhs[1]: nScansRequested
	int nScansRequested;
	if ((nrhs < 2) || mxIsEmpty(prhs[1]) || mxIsInf(mxGetScalar(prhs[1])))
	    {
		if (!isTaskBuffered)
			nScansRequested = 1;
		else
			nScansRequested = DAQmx_Val_Auto;
	    }
	else
        {
		nScansRequested = (int) mxGetScalar(prhs[1]);
        }
	
    // prhs[2]: outputFormat
	mxClassID outputDataClass;
    bool isMaxLinesPerChannelKnown = false ;
    uInt32 maxLinesPerChannel ;
	if ((nrhs < 3) || mxIsEmpty(prhs[2]))
	    {
		// Automatic determination of read type
		bool isLineBased = (bool) mxGetScalar(mxGetProperty(prhs[0],0,"isLineBasedDigital"));		

		if (!isTaskBuffered && isLineBased)  // This is a non-buffered, line-based Task: return data as a double array
			outputDataClass = mxDOUBLE_CLASS;
		else if (isTaskBuffered && isLineBased)  // This is a buffered, line-based Task: return data as a double array
			outputDataClass = mxDOUBLE_CLASS;
		else
		    {
            // The task has channels, one added per call to DAQmxCreateDIChan().  
            // Each channel has one or more TTL lines associated with it.  If you take the max of these numbers, 
            // across all the channels in the task, you get maxLinesPerChannel.
			status = DAQmxGetReadDigitalLinesBytesPerChan(taskID,&maxLinesPerChannel);  
			if (status)
				handleDAQmxError(status, "DAQmxGetReadDigitalLinesBytesPerChan");
            isMaxLinesPerChannelKnown = true ;

			if (maxLinesPerChannel <= 8)
				outputDataClass = mxUINT8_CLASS;
			else if (maxLinesPerChannel <= 16)
				outputDataClass = mxUINT16_CLASS;
			else if (maxLinesPerChannel <= 32)
				outputDataClass = mxUINT32_CLASS;
			else
				mexErrMsgTxt("It is not currently possible to read integer values from Task with greater than 32 lines per sample value");
		    }
	    }
	else
	    {
    	char outputFormat[10] ;
        mxGetString(prhs[2], outputFormat, 10);		

		if (_strcmpi(outputFormat,"uint8") == 0)
			outputDataClass = mxUINT8_CLASS;
		else if (_strcmpi(outputFormat,"uint16") == 0)
			outputDataClass = mxUINT16_CLASS;
		else if (_strcmpi(outputFormat,"uint32") == 0)
			outputDataClass = mxUINT32_CLASS;
		else if (_strcmpi(outputFormat,"double") == 0)
			outputDataClass = mxDOUBLE_CLASS;
		else if (_strcmpi(outputFormat,"logical") == 0)
			outputDataClass = mxLOGICAL_CLASS;
		else
			mexErrMsgTxt("The specified 'outputFormat' value (case-sensitive) is not recognized.");
	    }

	bool isRequestedOutputClassLogicalOrDouble;
	if ((outputDataClass == mxDOUBLE_CLASS) || (outputDataClass == mxLOGICAL_CLASS))
	    {
		isRequestedOutputClassLogicalOrDouble = true;
        if (!isMaxLinesPerChannelKnown)
		    {
			status = DAQmxGetReadDigitalLinesBytesPerChan(taskID,&maxLinesPerChannel);
			if (status)
				handleDAQmxError(status, "DAQmxGetReadDigitalLinesBytesPerChan");
            isMaxLinesPerChannelKnown = true ;
		    }			
	    }
	else
		isRequestedOutputClassLogicalOrDouble = false;

    // prhs[3]: timeout
	double timeout ;
	if ((nrhs < 4) || mxIsEmpty(prhs[3]) || mxIsInf(mxGetScalar(prhs[3])))
		timeout = DAQmx_Val_WaitInfinitely;
	else
		timeout = mxGetScalar(prhs[3]);

	// Determine # of channels
	uInt32 numChannels; 
	status = DAQmxGetReadNumChans(taskID, &numChannels);  // Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
	if (status)
		handleDAQmxError(status, "DAQmxGetReadNumChans");  // this terminates the mex function
	
    // Determine how many scans to *attempt* to read
    uInt32 nScansToAttemptToRead ;
	if (nScansRequested == DAQmx_Val_Auto)  // this means the user wants as many scans as are available
    	{
		status = DAQmxGetReadAvailSampPerChan(taskID, (uInt32 *)&nScansToAttemptToRead);
		if (status)
			handleDAQmxError(status, "DAQmxGetReadAvailSampPerChan");  // this terminates the mex function
	    }
    else
        {
        nScansToAttemptToRead = nScansRequested ;
        }
	
	// Allocate a buffer to store the data
	mwSize numRows ;
	if (isRequestedOutputClassLogicalOrDouble)
		numRows = (mwSize) (nScansToAttemptToRead * maxLinesPerChannel) ;
	else
		numRows = (mwSize) nScansToAttemptToRead ;
	
	mxArray *rawDataBuffer;
	if (outputDataClass == mxDOUBLE_CLASS)
	    {
		rawDataBuffer = mxCreateNumericMatrix(numRows,numChannels,mxUINT8_CLASS,mxREAL);
		//outputDataBufTrue = mxCreateDoubleMatrix(numRows,numChannels,mxREAL);
	    }
	else
        {
		rawDataBuffer = mxCreateNumericMatrix(numRows,numChannels,outputDataClass,mxREAL);
        }
    uInt32 nElementsInRawDataBuffer = (uInt32) numRows * numChannels ;
	void *rawDataBufferPtr = mxGetData(rawDataBuffer);

    // Dertermine how many scans 

	//Read data
	int32 nScansRead;
	int32 numBytesPerScan;

	// The DAQmx reading functions complain if you call them when there's no more data to read, even if you ask for zero scans.
	// So we don't attempt a read if nScansToAttemptToRead is zero.
	if (nScansToAttemptToRead>0)  
        {
		switch (outputDataClass)
		    {
		    case mxUINT8_CLASS:
			    status = DAQmxReadDigitalU8(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt8*) rawDataBufferPtr, nElementsInRawDataBuffer, &nScansRead, NULL);
			    break;
		    case mxUINT16_CLASS:
			    status = DAQmxReadDigitalU16(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt16*) rawDataBufferPtr, nElementsInRawDataBuffer, &nScansRead, NULL);
			    break;
		    case mxUINT32_CLASS:
			    status = DAQmxReadDigitalU32(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt32*) rawDataBufferPtr, nElementsInRawDataBuffer, &nScansRead, NULL);
			    break;
		    case mxLOGICAL_CLASS:
		    case mxDOUBLE_CLASS:
			    status = DAQmxReadDigitalLines(taskID, nScansToAttemptToRead, timeout, DAQmx_Val_GroupByChannel, (uInt8*) rawDataBufferPtr, nElementsInRawDataBuffer, &nScansRead, &numBytesPerScan, NULL);
			    break;
		    default:
			    mexErrMsgTxt("There must be two output arguments specified if a preallocated MATLAB variable is not specified");
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
	if (outputDataClass != mxDOUBLE_CLASS)
        {
        // This is the usual case
        plhs[0] = rawDataBuffer;
        }
    else
	    {
        // double output requires special handling
    	mxArray *outputDataBufTrue = mxCreateDoubleMatrix(numRows,numChannels,mxREAL) ;

		// Convert logical data to double type
		double *outputDataTruePtr = mxGetPr(outputDataBufTrue) ;
		for (size_t i=0; i < mxGetNumberOfElements(rawDataBuffer); i++)	
			*(outputDataTruePtr+i) = (double) *((uInt8 *)rawDataBufferPtr+i);
			
		mxDestroyArray(rawDataBuffer);  // this will happen on mex exit regardless...

		plhs[0] = outputDataBufTrue;
	    }

    // Assign to plhs[1], if requested
	if (nlhs>=2)  // Return number of samples actually read
    	{
		plhs[1] = mxCreateDoubleScalar(0);	
		double *nScansReadOutput = mxGetPr(plhs[1]);
		*nScansReadOutput = (double)nScansRead;
	    }

    }

