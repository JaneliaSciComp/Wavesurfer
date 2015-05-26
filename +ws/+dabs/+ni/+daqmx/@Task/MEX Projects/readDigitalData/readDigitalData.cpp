// readDigitalData.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "mex.h"
#include "NIDAQmx_mod.h"

#define MAXVARNAMESIZE 64


//% General method for reading digital data from a Task containing one or more digital input Channels
//%% function [outputData, sampsPerChanRead] = readDigitalData(task, numSampsPerChan, outputFormat, timeout, outputVarSizeOrName)
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

//Static variables
static bool32 fillMode = DAQmx_Val_GroupByChannel; //Arrange data by channel, so that columns correspond to channels given MATLAB's column-major data format

//Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	//Read input arguments
	char outputFormat[10];
	char outputVarName[MAXVARNAMESIZE];
	int	outputVarSampsPerChan;
	double timeout;
	int numSampsPerChan;
	bool outputData; //Indicates whether to return an outputData argument
	mxClassID outputDataClass;
	uInt32 bufSize;
	bool writeDigitalLines;
	uInt32 bytesPerChan=0;
	TaskHandle taskID, *taskIDPtr;
	int32 status;

	//Get TaskHandle
	taskIDPtr = (TaskHandle*)mxGetData(mxGetProperty(prhs[0],0, "taskID"));
	taskID = *taskIDPtr;

	//Determine if this is a buffered read operation
	status = DAQmxGetBufInputBufSize(taskID, &bufSize);
	if (status)
		handleDAQmxError(status, "DAQmxGetBufInputBufSize");

	//Handle input arguments
	if ((nrhs < 2) || mxIsEmpty(prhs[1]) || mxIsInf(mxGetScalar(prhs[1])))
	{
		if (bufSize==0)
			numSampsPerChan = 1;
		else
			numSampsPerChan = DAQmx_Val_Auto;
	}
	else
		numSampsPerChan = (int) mxGetScalar(prhs[1]);
	
	if ((nrhs < 3) || mxIsEmpty(prhs[2]))
	{
		//Automatic determination of read type
		bool isLineBased = (bool) mxGetScalar(mxGetProperty(prhs[0],0,"isLineBasedDigital"));		

		if ((bufSize==0) && isLineBased) //This is a non-buffered, line-based Task: return data as a double array
			outputDataClass = mxDOUBLE_CLASS;
		else if ((bufSize!=0 && isLineBased)) //This is a buffered, line-based Task: return data as a double array
			outputDataClass = mxDOUBLE_CLASS;
		else
		{
			status = DAQmxGetReadDigitalLinesBytesPerChan(taskID,&bytesPerChan); //This actually returns the number of bytes required to represent one sample of Channel data
			if (status)
				handleDAQmxError(status, "DAQmxGetReadDigitalLinesBytesPerChan");

			if (bytesPerChan <= 8)
				outputDataClass = mxUINT8_CLASS;
			else if (bytesPerChan <= 16)
				outputDataClass = mxUINT16_CLASS;
			else if (bytesPerChan <= 32)
				outputDataClass = mxUINT32_CLASS;
			else
				mexErrMsgTxt("It is not currently possible to read integer values from Task with greater than 32 lines per sample value");
		}
	}
	else
	{
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

	if ((outputDataClass == mxDOUBLE_CLASS) || (outputDataClass == mxLOGICAL_CLASS))
	{
		writeDigitalLines = true;
		if (bytesPerChan == 0)
		{
			status = DAQmxGetReadDigitalLinesBytesPerChan(taskID,&bytesPerChan); //This actually returns the number of bytes required to represent one sample of Channel data
			if (status)
				handleDAQmxError(status, "DAQmxGetReadDigitalLinesBytesPerChan");
		}			
	}
	else
		writeDigitalLines = false;


	if ((nrhs < 4) || mxIsEmpty(prhs[3]) || mxIsInf(mxGetScalar(prhs[3])))
		timeout = DAQmx_Val_WaitInfinitely;
	else
		timeout = mxGetScalar(prhs[3]);


	if ((nrhs < 5) || mxIsEmpty(prhs[4])) //OutputVarSizeOrName argument
	{
		outputData = true;
		outputVarSampsPerChan = numSampsPerChan; //If value is DAQmx_Val_Auto, then the # of samples available will be queried before allocting array
	}
	else
	{
		outputData = mxIsNumeric(prhs[4]);
		if (outputData)
		{
			if (nlhs < 2)
				mexErrMsgTxt("There must be two output arguments specified if a preallocated MATLAB variable is not specified");
			outputVarSampsPerChan = (int) mxGetScalar(prhs[4]);
		}
		else
			mxGetString(prhs[4], outputVarName, MAXVARNAMESIZE);
	}

	//Determin # of output channels
	uInt32 numChannels; 
	DAQmxGetReadNumChans(taskID, &numChannels); //Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
	
	//Determine output buffer/size (creating if needed)
	mxArray *outputDataBuf, *outputDataBufTrue;
	void *outputDataPtr;

	//float64 *outputDataPtr;
	if (outputData)
	{
		mwSize numRows;

		if (outputVarSampsPerChan == DAQmx_Val_Auto)
		{
			status = DAQmxGetReadAvailSampPerChan(taskID, (uInt32 *)&outputVarSampsPerChan);
			if (status)
			{
				handleDAQmxError(status, "DAQmxGetReadAvailSampPerChan");
				return;
			}
		}
		
		if (writeDigitalLines)
			numRows = (mwSize) (outputVarSampsPerChan * bytesPerChan);
		else
			numRows = (mwSize) outputVarSampsPerChan;
		
		if (outputDataClass == mxDOUBLE_CLASS)
		{
			outputDataBuf = mxCreateNumericMatrix(numRows,numChannels,mxUINT8_CLASS,mxREAL);
			outputDataBufTrue = mxCreateDoubleMatrix(numRows,numChannels,mxREAL);
		}
		else
			outputDataBuf = mxCreateNumericMatrix(numRows,numChannels,outputDataClass,mxREAL);
	}
	else //I don't believe this is working
	{
		outputDataBuf = mexGetVariable("caller", outputVarName);
		outputVarSampsPerChan = mxGetM(outputDataBuf);
		//TODO: Add check to ensure WS variable is of correct class
	}

	outputDataPtr = mxGetData(outputDataBuf);

	//Read data
	int32 numSampsRead;
	int32 numBytesPerSamp;

	// The DAQmx reading functions complain if you call them when there's no more data to read, even if you ask for zero scans.
	// So we don't attempt a read if numSampsPerChanToTryToRead is zero.
	if (numSampsPerChan>0)  {
		switch (outputDataClass)
		{
		case mxUINT8_CLASS:
			status = DAQmxReadDigitalU8(taskID, numSampsPerChan, timeout, fillMode, (uInt8*) outputDataPtr, outputVarSampsPerChan * numChannels, &numSampsRead, NULL);
			break;
		case mxUINT16_CLASS:
			status = DAQmxReadDigitalU16(taskID, numSampsPerChan, timeout, fillMode, (uInt16*) outputDataPtr, outputVarSampsPerChan * numChannels, &numSampsRead, NULL);
			break;
		case mxUINT32_CLASS:
			status = DAQmxReadDigitalU32(taskID, numSampsPerChan, timeout, fillMode, (uInt32*) outputDataPtr, outputVarSampsPerChan * numChannels, &numSampsRead, NULL);
			break;
		case mxLOGICAL_CLASS:
		case mxDOUBLE_CLASS:
			status = DAQmxReadDigitalLines(taskID, numSampsPerChan, timeout, fillMode, (uInt8*) outputDataPtr, outputVarSampsPerChan * numChannels * bytesPerChan, &numSampsRead, &numBytesPerSamp, NULL);
			break;
		default:
			mexErrMsgTxt("There must be two output arguments specified if a preallocated MATLAB variable is not specified");
		}
	}
	else  {
		numSampsRead=0;
		status=0;
	}


	//Return output data
	if (!status)
	{
		//mexPrintf("Successfully read %d samples of data\n", numSampsRead);		

		if (outputData)
		{
			if (nlhs > 0)
			{
				if (outputDataClass == mxDOUBLE_CLASS)
				{
					//Convert logical data to double type
					double *outputDataTruePtr = mxGetPr(outputDataBufTrue);
					for (size_t i=0;i < mxGetNumberOfElements(outputDataBuf);i++)	
						*(outputDataTruePtr+i) = (double) *((uInt8 *)outputDataPtr+i);
						
					mxDestroyArray(outputDataBuf);

					plhs[0] = outputDataBufTrue;
				}
				else
					plhs[0] = outputDataBuf;
			}
			else
				mxDestroyArray(outputDataBuf); //If you don't read out, all the reading was done for naught
		}
		else //I don't believe this is working
		{
			mexErrMsgTxt("invalid branch");
			mexPutVariable("caller", outputVarName, outputDataBuf);
			
			if (nlhs > 0) //Return empty value for output data
				plhs[0] = mxCreateDoubleMatrix(0,0,mxREAL);
		}			

		if (nlhs > 1) //Return number of samples actually read
		{
			double *sampsReadOutput;

			plhs[1] = mxCreateDoubleScalar(0);	
			sampsReadOutput = mxGetPr(plhs[1]);

			*sampsReadOutput = (double)numSampsRead;
		}
	}
	else //Read failed
		handleDAQmxError(status, mexFunctionName());

}

