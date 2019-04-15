function scalingCoefficients = getScalingCoefficientsOldStyle(taskName, referenceClockSource, referenceClockRate, deviceNames, terminalIDs, sampleRate, doUseDefaultTermination)
    % Deal with optional args
    if ~exist('doUseDefaultTermination','var') || isempty(doUseDefaultTermination) ,
        doUseDefaultTermination = false ;  % when false, all AI channels use differential termination
    end
    %IsUsingDefaultTermination_ = doUseDefaultTermination ;

    % Determine the task type, digital or analog
    %IsAnalog_ = ~isequal(taskType,'digital') ;
    %IsAnalog_ = true ;

    % Create the task, channels
    nChannels = length(terminalIDs) ;            
    if nChannels==0 ,
        scalingCoefficients = [] ;
        return
    end    
    taskHandle = ws.ni('DAQmxCreateTask', taskName) ;

    % Create a tic id
    %TicId_ = tic();

    % Store this stuff
    %DeviceNames_ = deviceNames ;
    %TerminalIDs_ = terminalIDs ;

    % Create the channels, set the timing mode (has to be done
    % after adding channels)
    termination = ws.fif(doUseDefaultTermination, 'DAQmx_Val_Cfg_Default', 'DAQmx_Val_Diff') ;
    for iChannel = 1:nChannels ,
        deviceName = deviceNames{iChannel} ;
        terminalID = terminalIDs(iChannel) ;
%                         DabsDaqTask_.createAIVoltageChan(deviceName, ...
%                                                               terminalID, ...
%                                                               [], ...
%                                                               -10, ...
%                                                               +10, ...
%                                                               'DAQmx_Val_Volts', ...
%                                                               [], ...
%                                                               termination) ;
        physicalChannelName = sprintf('%s/ai%d', deviceName, terminalID) ;                                  
        ws.ni('DAQmxCreateAIVoltageChan', ...
              taskHandle, ...
              physicalChannelName, ...
              termination) ;

    end
%                 [referenceClockSource, referenceClockRate] = ...
%                     ws.getReferenceClockSourceAndRate(primaryDeviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
    %set(DabsDaqTask_, 'refClkSrc', referenceClockSource) ;
    %set(DabsDaqTask_, 'refClkRate', referenceClockRate) ;
    ws.ni('DAQmxSetRefClkSrc', taskHandle, referenceClockSource) ;
    ws.ni('DAQmxSetRefClkRate', taskHandle, referenceClockRate) ;
    %DabsDaqTask_.cfgSampClkTiming(sampleRate, 'DAQmx_Val_FiniteSamps');
    source = '';  % means to use default sample clock
    scanCount = 2 ;
      % 2 is the minimum value advisable when using FiniteSamps mode. If this isn't
      % set, then Error -20077 can occur if writeXXX() operation precedes configuring
      % sampQuantSampPerChan property to a non-zero value -- a bit strange,
      % considering that it is allowed to buffer/write more data than specified to
      % generate.
    ws.ni('DAQmxCfgSampClkTiming', taskHandle, source, sampleRate, 'DAQmx_Val_Rising', 'DAQmx_Val_FiniteSamps', scanCount);
    try
        %DabsDaqTask_.control('DAQmx_Val_Task_Verify');
        ws.ni('DAQmxTaskControl', taskHandle, 'DAQmx_Val_Task_Verify');
    catch cause
        rawException = MException('ws:daqmx:taskFailedVerification', ...
                                  'There was a problem with the parameters of the input task, and it failed verification') ;
        exception = addCause(rawException, cause) ;
        throw(exception) ;
    end
    try
        %taskSampleClockRate = DabsDaqTask_.sampClkRate ;
        taskSampleClockRate = ws.ni('DAQmxGetSampClkRate', taskHandle) ;
    catch cause
        rawException = MException('ws:daqmx:errorGettingTaskSampleClockRate', ...
                                  'There was a problem getting the sample clock rate of the DAQmx task in order to check it') ;
        exception = addCause(rawException, cause) ;
        throw(exception) ;
    end                    
    if taskSampleClockRate ~= sampleRate ,
        error('ws:sampleClockRateNotEqualToDesiredClockRate', ...
              'Unable to set the DAQmx sample rate to the desired sampling rate');
    end

    % If analog, get the scaling coefficients
    %rawScalingCoefficients = DabsDaqTask_.getAIDevScalingCoeffs() ;   % nChannels x nCoefficients, low-order coeffs first
    %ScalingCoefficients_ = transpose(rawScalingCoefficients) ;  % nCoefficients x nChannels , low-order coeffs first
    scalingCoefficients =  ws.ni('DAQmxGetAIDevScalingCoeffs', taskHandle) ;   % nCoefficients x nChannelsThisDevice, low-order coeffs first

    % Delete the task
    if ~isempty(taskHandle) ,
        %delete(DabsDaqTask_) ;  % have to explicitly delete, b/c ws.dabs.ni.daqmx.System has refs to, I guess
        if ~ws.ni('DAQmxIsTaskDone', taskHandle) ,
            ws.ni('DAQmxStopTask', taskHandle) ;
        end
        ws.ni('DAQmxClearTask', taskHandle) ;
    end
    %DabsDaqTask_ = [] ;
end
