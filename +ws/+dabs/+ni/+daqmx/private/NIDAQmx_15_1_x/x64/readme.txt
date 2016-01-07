Thunk/prototype files created with Matlab 2015a, using Visual Studio
2008 compiler.

The command used was:

    loadlibrary('nicaiu.dll','NIDAQmx_mod.h','mfilename','NIDAQmx_proto')

There were some warnings, but no errors:

>> loadlibrary('nicaiu.dll','NIDAQmx_mod.h','mfilename','NIDAQmx_proto')
Warning: Warnings messages were produced while parsing.  Check the functions you intend to use for correctness.  Warning text can be viewed using:
 [notfound,warnings]=loadlibrary(...) 
> In loadlibrary (line 359) 
Warning: The data type 'error' used by function DAQmxGetTaskAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'FcnPtr' used by function DAQmxRegisterEveryNSamplesEvent does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'FcnPtr' used by function DAQmxRegisterDoneEvent does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'FcnPtr' used by function DAQmxRegisterSignalEvent does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetChanAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetChanAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetTimingAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetTimingAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetTimingAttributeEx does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetTimingAttributeEx does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetTrigAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetTrigAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetReadAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetReadAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetWriteAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetWriteAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetExportedSignalAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetExportedSignalAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetScaleAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetScaleAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetBufferAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetSwitchChanAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetSwitchDeviceAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetSwitchDeviceAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetSwitchScanAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetDeviceAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxCreateWatchdogTimerTask does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetWatchdogAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetWatchdogAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetCalInfoAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetCalInfoAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetPhysicalChanAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetRealTimeAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetRealTimeAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetPersistedTaskAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetPersistedChanAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetPersistedScaleAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetSystemInfoAttribute does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetDigitalPowerUpStates does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetDigitalPowerUpStates does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetDigitalPullUpPullDownStates does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetDigitalPullUpPullDownStates does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxSetAnalogPowerUpStates does not exist. 
> In loadlibrary (line 431) 
Warning: The data type 'error' used by function DAQmxGetAnalogPowerUpStates does not exist. 
> In loadlibrary (line 431) 
>> 
