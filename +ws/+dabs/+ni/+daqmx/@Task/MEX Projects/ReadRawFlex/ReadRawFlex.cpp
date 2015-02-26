// ReadRawFlex.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx_mod.h"

//Matlab signature
//[outData, sampsRead] = ReadRaw(task,numSampsPerChan, timeout, arraySizeInSamples)


//Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	TaskHandle task;
	int32 numSampsPerChan;
	float64 timeout;

	uInt32 numChannels;
	int32 totalNumSamples;
	uInt32 arraySizeInSamples;
	uInt32 arraySizeInBytes;	
	int32 sampsRead;
	int32 numBytesPerSamp;
	int16 *dataBuffer;
	int32 status;
	int32 errorStringSize;
	char *errorString;

	double *sampsReadOutput;

	//Parse input arguments
	task = (TaskHandle)mxGetScalar(prhs[0]);
	numSampsPerChan = (int32)mxGetScalar(prhs[1]);
	timeout = (float64)mxGetScalar(prhs[2]);
	arraySizeInSamples = (uInt32)mxGetScalar(prhs[3]);
	
	//Determine # of channels and amt. of memory to allocate
	DAQmxGetTaskNumChans(task, &numChannels);
	totalNumSamples = arraySizeInSamples * numChannels;
	arraySizeInBytes = totalNumSamples * sizeof(int16);

	//Create memory for output arguments
	plhs[0] = mxCreateNumericMatrix(totalNumSamples, 1, mxINT16_CLASS, mxREAL); 
	plhs[1] = mxCreateDoubleScalar(0);
	dataBuffer = (int16*)mxGetPr(plhs[0]);
	sampsReadOutput = mxGetPr(plhs[1]);
	
	//Call DAQmx function
	status = (int32) DAQmxReadRaw(task, numSampsPerChan, timeout, dataBuffer, arraySizeInBytes, &sampsRead, &numBytesPerSamp, NULL);

	//Return output buffer
	if (!status)
	{
		mexPrintf("Successfully read %d samples of data\n", sampsRead);		
		*sampsReadOutput = (double)sampsRead;
	}
	else
	{
		//Display error string
		errorStringSize = DAQmxGetErrorString(status,NULL,0); //Gets size of buffer
		errorString = (char *)mxCalloc(errorStringSize,sizeof(char));
		DAQmxGetErrorString(status,errorString,errorStringSize);
		mexPrintf("ERROR in %s: %s\n", mexFunctionName(), errorString);
		mxFree(errorString);

		//Return an empty array insead
		mxDestroyArray(plhs[0]); //I think this is kosher
		plhs[0] = mxCreateNumericMatrix(0, 0, mxINT16_CLASS, mxREAL);
	}

}


