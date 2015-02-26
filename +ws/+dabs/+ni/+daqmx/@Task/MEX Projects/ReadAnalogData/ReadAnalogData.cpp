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
//%% function [outputData, sampsPerChanRead] = readAnalogData(task, numSampsPerChan, outputFormat, timeout, outputVarSizeOrName)
//%	task: A DAQmx.Task object handle
//%	numSampsPerChan: <OPTIONAL - Default: inf> Specifies (maximum) number of samples per channel to read. If omitted/empty, value of 'inf' is used. If 'inf' or < 0, then all available samples are read, up to the size of the output array.
//%	outputFormat: <OPTIONAL - one of {'native' 'scaled'}> If omitted/empty, 'scaled' is assumed. Indicate native unscaled format and double scaled format, respectively.
//%   timeout: <OPTIONAL - Default: inf> Time, in seconds, to wait for function to complete read. If omitted/empty, value of 'inf' is used. If 'inf' or < 0, then function will wait indefinitely.
//%	outputVarSizeOrName: <OPTIONAL> Size in samples of output variable to create (to be returned as outputData argument). If empty/omitted, the output array size is determined automatically. 
//%                                   Alternatively, this may specify name of preallocated MATLAB variable into which to store read data.                                    
//%
//%   outputData: Array of output data with samples arranged in rows and channels in columns. This value is not output if outputVarOrSize is a string specifying a preallocated output variable.
//%   sampsPerChanRead: Number of samples actually read. This may be smaller than that specified/implied by outputVarOrSize.
//%
//%% NOTES
//%   The 'fillMode' parameter of DAQmx API functions is not supported -- data is always grouped by Channel (DAQmx_Val_GroupByChannel).
//%   This corresponds to Matlab matrix ordering where each Channel corresponds to one column. 
//
//%   If outputFormat='native', the data type is determined automatically, from the properties of Channels for this Task. May be one of 'uint16', 'int16', 'uint32', 'int32'.
//%
//%   At moment, the option to specify the name of a preallocated MATLAB variable, via the outputVarSizeOrName argument, is not supported.
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
	//Read input arguments

	// Get the task handle
	mxArray *mxTaskID = mxGetProperty(prhs[0],0,"taskID");
	mxClassID clsID = mxGetClassID(mxTaskID);
	localAssert(clsID==TASKHANDLE_MXCLASS);
	TaskHandle *taskIDPtr = (TaskHandle*)mxGetData(mxTaskID);
	TaskHandle taskID = *taskIDPtr;

	//Determine if this is a buffered read operation
	uInt32 bufSize = 0;
	int32 status = DAQmxGetBufInputBufSize(taskID,&bufSize);
	if (status) {
		handleDAQmxError(status,"DAQmxGetBufInputBufSize");
	}

	// Handle input arguments

	int32 numSampsPerChan = 0; // this does take negative vals in the case of DAQmx_Val_Auto
	if ((nrhs < 2) || mxIsEmpty(prhs[1]) || mxIsInf(mxGetScalar(prhs[1]))) {
		if (bufSize==0)
			numSampsPerChan = 1;
		else
			numSampsPerChan = DAQmx_Val_Auto;
	} else {
		numSampsPerChan = (int) mxGetScalar(prhs[1]);
	}
	
	char outputFormat[10];
	if ((nrhs < 3) || mxIsEmpty(prhs[2]))
		strcpy_s(outputFormat,"scaled");
	else
		mxGetString(prhs[2], outputFormat, 10);

	double timeout;
	if ((nrhs < 4) || mxIsEmpty(prhs[3]) || mxIsInf(mxGetScalar(prhs[3])))
		timeout = DAQmx_Val_WaitInfinitely;
	else
		timeout = mxGetScalar(prhs[3]);

	bool outputData; //Indicates whether to return an outputData argument
	int outputVarSampsPerChan = 0; // this CAN take negative values in case of DAQmx_Val_Auto
	char outputVarName[MAXVARNAMESIZE];	
	if ((nrhs < 5) || mxIsEmpty(prhs[4])) {
		outputData = true;
		outputVarSampsPerChan = numSampsPerChan; //If value is DAQmx_Val_Auto, then the # of samples available will be queried before allocting array
	} else {
		outputData = mxIsNumeric(prhs[4]);
		if (outputData) {
			if (nlhs < 2) {
				mexErrMsgTxt("There must be two output arguments specified if a preallocated MATLAB variable is not specified");
			}
			outputVarSampsPerChan = (int) mxGetScalar(prhs[4]);
		} else {
			mxGetString(prhs[4],outputVarName,MAXVARNAMESIZE);
		}
	}

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

	//Determine # of output channels
	uInt32 numChannels; 
	DAQmxGetReadNumChans(taskID,&numChannels); //Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
	
	//Determine output buffer/size (creating if needed)
	mxArray *mxOutputDataBuf = NULL;
	if (outputData)	{
		if (outputVarSampsPerChan == DAQmx_Val_Auto) {
			uInt32 buf = 0;
			status = DAQmxGetReadAvailSampPerChan(taskID,&buf);
			if (status) {
				handleDAQmxError(status, mexFunctionName());
			}
			outputVarSampsPerChan = buf;
		}

		//localAssert(outputVarSampsPerChan >= 0);
		localAssert(outputVarSampsPerChan > 0);
		mxOutputDataBuf = mxCreateNumericMatrix(outputVarSampsPerChan,numChannels,outputDataClass,mxREAL);
	} else {
		localAssert(false);
		////I don't believe this is working
		//mxOutputDataBuf = mexGetVariable("caller", outputVarName);
		//outputVarSampsPerChan = mxGetM(mxOutputDataBuf);
		////TODO: Add check to ensure WS variable is of correct class
	}

	void* outputDataPtr = mxGetData(mxOutputDataBuf);
	localAssert(outputDataPtr!=NULL);

	uInt32 arraySizeInSamps = outputVarSampsPerChan * numChannels;
	localAssert(mxGetNumberOfElements(mxOutputDataBuf)==(size_t)arraySizeInSamps);
	int32 numSampsPerChanRead;

	
	if (outputDataClass == mxDOUBLE_CLASS) //'scaled' 
		// float64 should be double
		status = DAQmxReadAnalogF64(taskID,numSampsPerChan,timeout,fillMode,
				(float64*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
	else { //'raw'
		switch (outputDataClass)
		{
			case mxINT16_CLASS:
				status = DAQmxReadBinaryI16(taskID, numSampsPerChan, timeout, fillMode, (int16*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
				break;
			case mxINT32_CLASS:
				status = DAQmxReadBinaryI32(taskID, numSampsPerChan, timeout, fillMode, (int32*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
				break;
			case mxUINT16_CLASS:
				status = DAQmxReadBinaryU16(taskID, numSampsPerChan, timeout, fillMode, (uInt16*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
				break;
			case mxUINT32_CLASS:
				status = DAQmxReadBinaryU32(taskID, numSampsPerChan, timeout, fillMode, (uInt32*) outputDataPtr, arraySizeInSamps, &numSampsPerChanRead, NULL);
				break;
		}
	}

	//Return output data
	if (!status)
	{
		//mexPrintf("Successfully read %d samples of data\n", numSampsRead);

		if (outputData) {
			if (nlhs > 0)
				plhs[0] = mxOutputDataBuf;
			else				
				mxDestroyArray(mxOutputDataBuf); //If you don't read out, all the reading was done for naught
		} else {
			//I don't believe this is working
			localAssert(false);
			//mexPutVariable("caller", outputVarName, mxOutputDataBuf);
			//
			//if (nlhs >= 0) //Return empty value for output data
			//	plhs[0] = mxCreateDoubleMatrix(0,0,mxREAL);
		}
			

		if (nlhs>1) { //Return number of samples actually read
			plhs[1] = mxCreateDoubleScalar(0.0);	
			double *sampsReadOutput = mxGetPr(plhs[1]);
			*sampsReadOutput = (double)numSampsPerChanRead;
		}
	} else { //Read failed
		handleDAQmxError(status, mexFunctionName());
	}

}

