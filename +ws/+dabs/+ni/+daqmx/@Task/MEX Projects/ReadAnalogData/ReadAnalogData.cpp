// ReadAnalogData.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx.h"

//AL 9/15/2011. After getting NIDAQmx msotly working on win7 64bit, SI3.x was crashing during testing. 
// Investigation pointed to these MEX files. I went through this file closely and found a couple memory 
// corruptions. Similar memory bugs were found in ReadDigitalData, WriteAnalogData, WriteDigitalData. 
// Fixing these bugs seemed to remove instability in SI3.x on win7 64-bit. My point here however is
// to note that I went through this file closely, but did not go through the other three (ReadDigitalData)
// closely. (I just fixed the obvious memory bugs at-a-glance.) So this file should be relatively clean 
// and the others less so.

#define MAXVARNAMESIZE 64

// AL: This is a little silly but I am doing it to do some checking below.
#ifdef _WIN64
#define TASKHANDLE_MXCLASS mxUINT64_CLASS
#else
#define TASKHANDLE_MXCLASS mxUINT32_CLASS
#endif

//% General method for reading analog data from a Task containing one or more analog input Channels
//%% function [outputData, sampsPerChanRead] = readAnalogData(task, numSampsPerChanRequested, outputFormat, timeout)
//%	task: A DAQmx.Task object handle
//%	numSampsPerChanRequested: <OPTIONAL - Default: inf> Specifies (maximum) number of samples per channel to read. If omitted/empty, value of 'inf' is used. If 'inf' or < 0, then all available samples are read, up to the size of the output array.
//%	outputFormat: <OPTIONAL - one of {'native' 'scaled'}> If omitted/empty, 'scaled' is assumed. Indicate native unscaled format and double scaled format, respectively.
//%   timeout: <OPTIONAL - Default: inf> Time, in seconds, to wait for function to complete read. If omitted/empty, value of 'inf' is used. If 'inf' or < 0, then function will wait indefinitely.
//%
//%   outputData: Array of output data with samples arranged in rows and channels in columns.
//%   sampsPerChanRead: Number of samples actually read. This may be smaller than that specified/implied by outputVarOrSize.
//%
//%% NOTES
//%   The 'fillMode' parameter of DAQmx API functions is not supported -- data is always grouped by Channel (DAQmx_Val_GroupByChannel).
//%   This corresponds to Matlab matrix ordering where each Channel corresponds to one column. 
//
//%   If outputFormat='native', the data type is determined automatically, from the properties of Channels for this Task. May be one of 'uint16', 'int16', 'uint32', 'int32'.
//%

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
	mexErrMsgTxt(finalErrorString); // leaks finalErrorString
}

#define localAssert(tf) _localAssert(__FILE__,__LINE__,__FUNCTION__,#tf,tf)
void _localAssert(const char* file, int line, const char* func, const char* expr, bool tf) {
    char errorText[1024];
	if (!tf) {
		sprintf_s(errorText,"Assertion failed in ReadAnalogData.cpp: %s(%d) -- %s()\t%s\n",file,line,func,expr);
        mexPrintf(errorText);
		mexErrMsgTxt(errorText);
		//mexErrMsgTxt("idiot!");
	}
}

//Static variables
static bool32 fillMode = DAQmx_Val_GroupByChannel; //Arrange data by channel, so that columns correspond to channels given MATLAB's column-major data format

// [outputData, sampsPerChanRead] = readAnalogData(task, numSampsPerChan, outputFormat, timeout, outputVarSizeOrName)
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	//
	// Read input arguments
	//

	// prhs[0]: task
	// prhs[1]: numSampsPerChanRequested
	// prhs[2]: outputFormat
	// prhs[3]: timeout
	// prhs[4]: outputVarSizeOrName

	// prhs[0]: task
	// Get the task handle
	mxArray *mxTaskID = mxGetProperty(prhs[0],0,"taskID");
	mxClassID clsID = mxGetClassID(mxTaskID);
	localAssert(clsID==TASKHANDLE_MXCLASS);
	TaskHandle *taskIDPtr = (TaskHandle*)mxGetData(mxTaskID);
	TaskHandle taskID = *taskIDPtr;

	// Determine if this is a buffered read operation
	uInt32 bufSize = 0;
	int32 status = DAQmxGetBufInputBufSize(taskID,&bufSize);
	if (status) {
		handleDAQmxError(status,"DAQmxGetBufInputBufSize");
	}

	// prhs[1]: numSampsPerChanRequested
	int32 numSampsPerChanRequested;  // this does take negative vals in the case of DAQmx_Val_Auto
	if ((nrhs < 2) || mxIsEmpty(prhs[1]) || mxIsInf(mxGetScalar(prhs[1]))) {
		if (bufSize==0)
			numSampsPerChanRequested = 1;
		else
			numSampsPerChanRequested = DAQmx_Val_Auto;
	} else {
		numSampsPerChanRequested = (int) mxGetScalar(prhs[1]);
		if (numSampsPerChanRequested<0)  {
			numSampsPerChanRequested = DAQmx_Val_Auto;
		}
	}
	
	// prhs[2]: outputFormat
	char outputFormat[10];
	if ((nrhs < 3) || mxIsEmpty(prhs[2]))
		strcpy_s(outputFormat,"scaled");
	else
		mxGetString(prhs[2], outputFormat, 10);

	// prhs[3]: timeout
	double timeout;
	if ((nrhs < 4) || mxIsEmpty(prhs[3]) || mxIsInf(mxGetScalar(prhs[3])))
		timeout = DAQmx_Val_WaitInfinitely;
	else
		timeout = mxGetScalar(prhs[3]);

	//// prhs[4]: outputVarSizeOrName
	//bool outputData; //Indicates whether to return an outputData argument
	//int outputVarSampsPerChan = 0; // this CAN take negative values in case of DAQmx_Val_Auto
	//char outputVarName[MAXVARNAMESIZE];	
	////if ((nrhs < 5) || mxIsEmpty(prhs[4])) {
	//if (true) {
	//	outputData = true;
	//	outputVarSampsPerChan = numSampsPerChanRequested; //If value is DAQmx_Val_Auto, then the # of samples available will be queried before allocting array
	//} else {
	//	outputData = mxIsNumeric(prhs[4]);
	//	if (outputData) {
	//		if (nlhs < 2) {
	//			mexErrMsgTxt("There must be two output arguments specified if a preallocated MATLAB variable is not specified");
	//		}
	//		outputVarSampsPerChan = (int) mxGetScalar(prhs[4]);
	//	} else {
	//		mxGetString(prhs[4],outputVarName,MAXVARNAMESIZE);
	//	}
	//}

	//Determine output data type
	mxClassID outputDataClass;
	mxArray *mxRawDataArrayAI = mxGetProperty(prhs[0],0,"rawDataArrayAI"); //Stored in MCOS Task object as an empty array of the desired class!
	mxClassID rawDataClass = mxGetClassID(mxRawDataArrayAI); 

	char errorMessage[30];
	if (!_strcmpi(outputFormat,"scaled"))
		outputDataClass = mxDOUBLE_CLASS;
	else if (!_strcmpi(outputFormat,"native"))
		outputDataClass = rawDataClass;
	else {
		sprintf_s(errorMessage,"Unrecognized output format: %s\n",outputFormat);
		mexErrMsgTxt(errorMessage);
	}		

	// Determine # of output channels
	uInt32 numChannels; 
	DAQmxGetReadNumChans(taskID,&numChannels); //Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
	
	// Determine the number of samples to try to read.
	// If user has requested all the sample available, find out how many that is.
	int32 numSampsPerChanToTryToRead;
	if (numSampsPerChanRequested == DAQmx_Val_Auto) {
		// In this case, have to find out how many scans are available
		uInt32 buf = 0;
		status = DAQmxGetReadAvailSampPerChan(taskID,&buf);
		if (status) {
			handleDAQmxError(status, mexFunctionName());
		}
		numSampsPerChanToTryToRead = buf;
	}
	else {
	    numSampsPerChanToTryToRead = numSampsPerChanRequested ;
	}

	// Sanity check
	localAssert(numSampsPerChanToTryToRead >= 0);

	// Allocate the output buffer
	mxArray *mxOutputDataBuf = mxCreateNumericMatrix(numSampsPerChanToTryToRead,numChannels,outputDataClass,mxREAL);

	// Get a pointer to the storage for the output buffer
	void* outputDataPtr = mxGetData(mxOutputDataBuf);
	//localAssert(outputDataPtr!=NULL);  // This can happen, and it's not a problem, if e.g. there are zero scans available

	// Check that the array size is correct (I guess to guard against allocation failures?)
	uInt32 arraySizeInSamps = numSampsPerChanToTryToRead * numChannels;
	localAssert(mxGetNumberOfElements(mxOutputDataBuf)==(size_t)arraySizeInSamps);

	// Read the data
	//mexPrintf("About to try to read %d scans of data\n", numSampsPerChanToTryToRead);
	int32 numSampsPerChanRead;
	// The daqmx reading functions complain if you call them when there's no more data to read, even if you ask for zero scans.
	// So we don't attempt a read if numSampsPerChanToTryToRead is zero.
	if (numSampsPerChanToTryToRead>0)  {
		if (outputDataClass == mxDOUBLE_CLASS) { //'scaled' 
			// float64 should be double
			status = DAQmxReadAnalogF64(taskID,numSampsPerChanToTryToRead,timeout,fillMode,
					(float64*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
		}
		else { //'raw'
			switch (outputDataClass)
			{
				case mxINT16_CLASS:
					status = DAQmxReadBinaryI16(taskID, numSampsPerChanToTryToRead, timeout, fillMode, (int16*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
					break;
				case mxINT32_CLASS:
					status = DAQmxReadBinaryI32(taskID, numSampsPerChanToTryToRead, timeout, fillMode, (int32*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
					break;
				case mxUINT16_CLASS:
					status = DAQmxReadBinaryU16(taskID, numSampsPerChanToTryToRead, timeout, fillMode, (uInt16*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
					break;
				case mxUINT32_CLASS:
					status = DAQmxReadBinaryU32(taskID, numSampsPerChanToTryToRead, timeout, fillMode, (uInt32*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
					break;
			}
		}
	}
	else  {
		numSampsPerChanRead = 0 ;
		status = 0 ;
	}

    // Check for a read failure
	if (status) {
		handleDAQmxError(status, mexFunctionName());
	}

	// Return output data
	plhs[0] = mxOutputDataBuf;  // even if nlhs==0, still safe to assign to plhs[0], and should do this, so ans gets assigned
		
	// Return the number of samples actually read, if there's a LHS arg to hold it
	if (nlhs>=2) { 
		plhs[1] = mxCreateDoubleScalar(0.0);	
		double *sampsReadOutput = mxGetPr(plhs[1]);
		*sampsReadOutput = (double)numSampsPerChanRead;
	}

}

