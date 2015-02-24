#include "RegisterXXXCallback.h"

typedef struct {
	bool readDataEnable;
	mxClassID readDataClass;
	float64 readTimeout;
	const char *taskType;
	uInt32 numChannels;
} EveryNCallbackData;

const char *ANALOGINPUTTASKTYPE = "AnalogInput";
const char *DIGITALINPUTTASKTYPE = "DigitalInput";
const char *COUNTERINPUTTASKTYPE = "CounterInput";
const char *OUTPUTTASKTYPE = "*Output";

int32 CVICALLBACK callbackWrapperNEvent(TaskHandle taskHandle, 
										int32 everyNsamplesEventType, 
										uInt32 nSamples, void *callbackData)
{
	assert(callbackData);
	CallbackData *cbd = (CallbackData*)callbackData;
	assert(cbd->callbackTypeData);
	EveryNCallbackData *encbd = (EveryNCallbackData*)cbd->callbackTypeData;
	mxArray *evtData = cbd->eventData;
	assert(evtData);

#if DEBUG_MEX
	mexPrintf("in callbackWrapperNEvent");
#endif

	// These variables are for dealing with errors during data read.
	bool wasErrorDuringRead = false;
	mxArray *mxDataCache = NULL;

	// Read data if appropriate; effect is to load up pre-allocated evtData.data 
	// and/or fill evtData.errorMessage in case of error.
	if (encbd->readDataEnable) {

		const char *type = encbd->taskType;
		if (strcmp(type,"AnalogInput")==0) {

			uInt32 numChannels = 0; 
			DAQmxGetReadNumChans(taskHandle, &numChannels); //Reflects number of channels in Task, or the number of channels specified by 'ReadChannelsToRead' property
			uInt32 numDataElementsToRead = nSamples*numChannels;

			// eventData.data should be preallocated. eventData.errorMessage should be NULL
			mxArray *dataArray = mxGetField(evtData,0,"data");
			assert(dataArray);
			void *dataPtr = mxGetData(dataArray);
			assert(dataPtr);
			mxArray *errMsgArray = mxGetField(evtData,0,"errorMessage");
			assert(errMsgArray==NULL); // should be empty

			// check that the dataArray we preallocated is the right size for the data we are about to read
			size_t numElDataArray = mxGetNumberOfElements(dataArray);
			if (numElDataArray!=numDataElementsToRead) {
				// major fail, something is wrong. Print a warning, then only read as much data as we have room for. (This will lead to a hard err later haha)
				mexPrintf("WARNING: everyN callback size mismatch between preallocated data array and expected number of sample reads.\n");
				numDataElementsToRead = numElDataArray;
			}

			bool32 fillMode = DAQmx_Val_GroupByChannel; //Arrange data by channel, so that columns correspond to channels given MATLAB's column-major data format
			int32 status = -1;
			int32 numSampsRead = -1;

			switch (encbd->readDataClass) {
				case mxDOUBLE_CLASS: //'scaled'
					status = DAQmxReadAnalogF64(taskHandle, nSamples, encbd->readTimeout, fillMode, (float64*) dataPtr, numDataElementsToRead, &numSampsRead, NULL);
					break;
				case mxINT16_CLASS: //'raw' from here to bottom
					status = DAQmxReadBinaryI16(taskHandle, nSamples, encbd->readTimeout, fillMode, (int16*) dataPtr, numDataElementsToRead, &numSampsRead, NULL);
					break;
				case mxINT32_CLASS:
					status = DAQmxReadBinaryI32(taskHandle, nSamples, encbd->readTimeout, fillMode, (int32*) dataPtr, numDataElementsToRead, &numSampsRead, NULL);
					break;
				case mxUINT16_CLASS:
					status = DAQmxReadBinaryU16(taskHandle, nSamples, encbd->readTimeout, fillMode, (uInt16*) dataPtr, numDataElementsToRead, &numSampsRead, NULL);
					break;
				case mxUINT32_CLASS:
					status = DAQmxReadBinaryU32(taskHandle, nSamples, encbd->readTimeout, fillMode, (uInt32*) dataPtr, numDataElementsToRead, &numSampsRead, NULL);
					break;
				default:
					assert(false);
			}

			// If there is an error:
			// * Set "errorMessage" field in eventData 
			// * Clear out "data" field

			mxArray *errorMessage = NULL;
			if (numSampsRead != nSamples) {
				errorMessage = mxCreateString("Number of samples read did not match that expected");
			} else if (status != 0) {
				//Display DAQmx error string
				int32 errorStringSize = DAQmxGetErrorString(status,NULL,0); //Gets size of buffer
				char *errorString = (char *)mxCalloc(errorStringSize,sizeof(char));
				DAQmxGetErrorString(status,errorString,errorStringSize);
				errorMessage = mxCreateString(errorString);
				mxFree(errorString);
			} else { 
				//Success
			}

			if (errorMessage!=NULL) {
				wasErrorDuringRead = true;
				mxSetField(evtData,0,"errorMessage",errorMessage);
				mxDataCache = mxGetField(evtData,0,"data");
				mxSetField(evtData,0,"data",NULL); // set data field to NULL so it appears as [] in MATLAB
			}

		} else if (strcmp(type,"DigitalInput")==0) {
			assert(false);
		} else if (strcmp(type,"CounterInput")==0) {
			assert(false);
		} else {
			assert(false);
		}
	}

	int32 returnval = callbackWrapper(taskHandle,everyNsamplesEventType,cbd);

	if (wasErrorDuringRead) {
		mxArray *errMsg = mxGetField(evtData,0,"errorMessage");
		assert(errMsg!=NULL);
		mxDestroyArray(errMsg);
		mxSetField(evtData,0,"errorMessage",NULL);

		assert(mxGetField(evtData,0,"data")==NULL);
		assert(mxDataCache!=NULL);
		mxSetField(evtData,0,"data",mxDataCache);
	}

	return returnval;
}

// Utility to get the eventType and taskType. Return true on success, false on fail.
// No throw
bool getEventType(int32 *eventType, const char **taskType, const mxArray *taskObj)
{
	char taskTypeArr[100];
	if (mxGetString(mxGetProperty(taskObj,0,"taskType"),taskTypeArr,100)) {
		*eventType = 0;
		*taskType = NULL;
		return false;
	}

	bool failed = false;
	if (!_strcmpi(taskTypeArr, "AnalogInput")) {
		*eventType = DAQmx_Val_Acquired_Into_Buffer;
		*taskType = ANALOGINPUTTASKTYPE;
	} else if (!_strcmpi(taskTypeArr, "DigitalInput")) {
		*eventType = DAQmx_Val_Acquired_Into_Buffer;
		*taskType = DIGITALINPUTTASKTYPE;
	} else if (!_strcmpi(taskTypeArr,"CounterInput")) {
		*eventType = DAQmx_Val_Acquired_Into_Buffer;
		*taskType = COUNTERINPUTTASKTYPE;
	} else if (!_strcmpi(taskTypeArr, "AnalogOutput") || 
			   !_strcmpi(taskTypeArr, "DigitalOutput") || 
			   !_strcmpi(taskTypeArr, "CounterOutput")) {
		*eventType = DAQmx_Val_Transferred_From_Buffer;
		*taskType = OUTPUTTASKTYPE;
	} else {
		*eventType = 0;
		*taskType = NULL;
		failed = true;
	}

	return !failed;
}

// Throws in extremely rare situations.
CallbackData *createEveryNCBD(const mxArray *taskObj, TaskHandle taskID, const char *taskType, int everyNSamples)
{
	mxArray *readDataEnableProp = mxGetProperty(taskObj,0,"everyNSamplesReadDataEnable");
	assert(readDataEnableProp);
	assert(mxIsLogical(readDataEnableProp));
	mxLogical *tmp = mxGetLogicals(readDataEnableProp);
	bool readDataEnable = (bool)*tmp;
	mxDestroyArray(readDataEnableProp);

	mxArray *readDataClassProp = mxGetProperty(taskObj,0,"everyNSamplesReadDataClass");
	assert(readDataClassProp);
	mxClassID readDataClass = mxGetClassID(readDataClassProp);
	mxDestroyArray(readDataClassProp);
	
	mxArray *readTimeOutProp = mxGetProperty(taskObj,0,"everyNSamplesReadTimeOut");
	assert(readTimeOutProp);
	assert(mxGetNumberOfElements(readTimeOutProp)==1);
	float64 readTimeout = (float64) mxGetScalar(readTimeOutProp);
	if (mxIsInf(readTimeout))
		readTimeout = DAQmx_Val_WaitInfinitely; 
	mxDestroyArray(readTimeOutProp);

	uInt32 numChannels = 0;
	if (DAQmxGetReadNumChans(taskID, &numChannels)!=0) {
		mexErrMsgTxt("Error registering callback."); // extremely extremely rare
	}
	assert(numChannels>0);

	EveryNCallbackData *encbd = (EveryNCallbackData*) mxCalloc(1,sizeof(EveryNCallbackData));
	if (encbd==NULL) {
		mexErrMsgTxt("Out of memory.");
	}
	mexMakeMemoryPersistent(encbd);
	encbd->readDataEnable = readDataEnable;
	encbd->readDataClass = readDataClass;
	encbd->readTimeout = readTimeout;
	encbd->taskType = taskType;
	encbd->numChannels = numChannels;

	const char *fnames[] = {"data","errorMessage"};
	mxArray *evtData = mxCreateStructMatrix(1,1,2,fnames);
	if (evtData==NULL) {
		mexErrMsgTxt("Out of memory.");
	}
	mexMakeArrayPersistent(evtData);
	mxSetField(evtData,0,"data",NULL);
	mxSetField(evtData,0,"errorMessage",NULL);

	if (readDataEnable) {
		// preallocate the data matrix.
		mxArray *evtDataArray = mxCreateNumericMatrix(everyNSamples,numChannels,readDataClass,mxREAL);
		if (evtDataArray==NULL) {
			mexErrMsgTxt("Out of memory.");
		}
		mexMakeArrayPersistent(evtDataArray);
		mxSetField(evtData,0,"data",evtDataArray);
	}
		
	CallbackData *cbd = CBDCreate(taskObj,EVERY_N_EVENT,"everyNSamplesEventCallbacks",evtData,encbd); // throws in extremely rare
	return cbd;
}





	
//status = RegisterEveryNCallback(taskObj,registerTF)
//
//taskObj: Handle to Devices.NI.DAQmx.Task object for which event is being registered/unregistered
//registerTF: Logical value. True=register the EveryNSamples event (using info from taskObj props). False=unregister.
//status: If there is a failure during a DAQmx call, the failure status code is returned.
//
//Throws mexErrs in very unusual circumstances. 
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
	if (!mexIsLocked())	{
		mexLock();
		mexAtExit(cleanUp);
	}

	//Parse general input arguments
	bool registerTF;
	TaskHandle taskID;
	parseGeneralInputs(nrhs, prhs, &registerTF, &taskID);

#if DEBUG_MEX
	mexPrintf("regEN. taskID %d registerTF %d.\n", taskID, registerTF ? 1 : 0);
#endif

	assert(nrhs>=1);
	const mxArray *taskObj = prhs[0];
	mxArray *mxNSamp = mxGetProperty(taskObj,0,"everyNSamples");
	assert(mxNSamp);
	uInt32 everyNSamples = (uInt32)mxGetScalar(mxNSamp);
	mxDestroyArray(mxNSamp);

	int32 eventType;
	const char *taskType = NULL;
	if (!getEventType(&eventType,&taskType,taskObj)) {
		mexErrMsgTxt("Unknown Task type. Cannot register callback.");
	}
	assert(taskType!=NULL);
	
	//Determine whether to register
	bool isRegistered = CBDStoreIsRegistered(taskID);
	int32 status = -1;
	if (registerTF) {
		if (isRegistered) {
			mexErrMsgTxt("TaskID/Event combo already registered.");
		}

		CallbackData *cbd = createEveryNCBD(taskObj,taskID,taskType,everyNSamples); // very rarely throws

		// We get the ReadChannelsToRead and reset it after the DAQmxRegisterEveryNSamplesEvent call.
		// We do this because we have found DAQmxRegister... to change the ReadChannelsToRead property.
		char readChansToReadBuf[256];
		status = DAQmxGetReadChannelsToRead(taskID,readChansToReadBuf,255);
		if (status!=0) {
#if DEBUG_MEX
	mexPrintf("Err!\n");
#endif
			CBDDestroy(cbd);
			nlhs = 1;
			plhs[0] = mxCreateDoubleScalar(status);
			return;
		}

#if DEBUG_MEX
	mexPrintf("Registering. readchanstoread is %s\n",readChansToReadBuf);
#endif

		int32 (*funcPtr)(TaskHandle, int32, uInt32, void*) = callbackWrapperNEvent;
		status = DAQmxRegisterEveryNSamplesEvent(taskID,eventType,everyNSamples,
				DAQmx_Val_SynchronousEventCallbacks, funcPtr, cbd);
		if (status!=0) {
#if DEBUG_MEX
	mexPrintf("Err!\n");
#endif
			CBDDestroy(cbd);
			nlhs = 1;
			plhs[0] = mxCreateDoubleScalar(status);
			return;
		}

#if DEBUG_MEX
	char buf1[256];
	DAQmxGetReadChannelsToRead(taskID,buf1,255);
	mexPrintf("Registering2. readchanstoread is %s\n",buf1);
#endif

		status = DAQmxResetReadChannelsToRead(taskID);
		if (status!=0) {
#if DEBUG_MEX
	mexPrintf("Err!\n");
#endif
			CBDDestroy(cbd);
			nlhs = 1;
			plhs[0] = mxCreateDoubleScalar(status);
			return;
		}

		status = DAQmxSetReadChannelsToRead(taskID,readChansToReadBuf);
		if (status!=0) {
#if DEBUG_MEX
	mexPrintf("Err!\n");
#endif
			CBDDestroy(cbd);
			nlhs = 1;
			plhs[0] = mxCreateDoubleScalar(status);
			return;
		}

#if DEBUG_MEX
	char buf2[256];
	DAQmxGetReadChannelsToRead(taskID,buf2,255);
	mexPrintf("Registering2. readchanstoread is %s\n",buf2);
#endif

		CBDStoreAddCallbackData(taskID,cbd);
	} else { // unregister
#if DEBUG_MEX
	mexPrintf("Unregister everyN\n");
#endif
		status = DAQmxRegisterEveryNSamplesEvent(taskID,eventType,100000,
			DAQmx_Val_SynchronousEventCallbacks, 0, 0);
		CBDStoreRmCallbackData(taskID);
	}
	
	nlhs = 1;
	plhs[0] = mxCreateDoubleScalar(status);
}
