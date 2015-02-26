// DriverBenchmark.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"


static float64 outputData[1500000]; //Initializes an array of zeros


//Gateway routine
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{

	TaskHandle task,task2;
	float64 sampleRate = 100000;
	float64 acqTime = 5;
	uInt64 numSamples = (uInt64) sampleRate * acqTime;
	char chanName[128];
	int32 sampsWritten;
	

	//Create the task
	DAQmxCreateTask("",&task);
	DAQmxCreateTask("",&task2);
	
	//Add AI channels to task
	DAQmxCreateAIVoltageChan(task, "Dev1/ai0:2", "ScanImageAcq", -1, -1, 1, DAQmx_Val_Volts, NULL);
	DAQmxCreateAOVoltageChan(task2, "Dev1/ao0:2", "ScanImageControl", -1, 1, DAQmx_Val_Volts, NULL);

	//Configure task timing
	DAQmxCfgSampClkTiming(task, NULL, 100000, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, numSamples);
	DAQmxCfgSampClkTiming(task2, NULL, 100000, DAQmx_Val_Rising, DAQmx_Val_FiniteSamps, numSamples);

	//Configure some task properties
	for (int i=0; i<2; i++)
	{
		sprintf_s(chanName, "Dev1/ai%d", i);
		DAQmxSetAIMax(task, chanName, 10);
		DAQmxSetAIMax(task, chanName, -10);
	}

	//Write some data
	DAQmxWriteAnalogF64(task, (int32) numSamples, false, -1, DAQmx_Val_GroupByChannel, outputData, &sampsWritten, NULL);

	//Screw it
	DAQmxClearTask(task);


}
