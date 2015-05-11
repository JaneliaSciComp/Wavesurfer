classdef Task < ws.dabs.ni.daqmx.private.DAQmxClass
    %TASK An object encapsulating an NI DAQmx 'task'
    %A 'task' is a collection of one or more channels of the same type (e.g. 'AnalogInput', 'DigitalOutput', etc) plus associated timing properties
    %
    %% CHANGES
    %   VI120110A: On all DAQmxRegisterEveryNSamples()/cfgInputBuffer() calls, make sure the readChannelsToRead property is not changed as a side effect (unexpected/unexplained) -- Vijay Iyer 12/1/10
    %   AL120810: Protect against empty taskType to get rid of warning on destruction of unconfigured tasks
    %   VI052611A: Revert VI120110A; NI fixed issue as of DAQmx 9.3 (CAR 277095) -- Vijay Iyer 5/26/11
    %% *****************************************
    
    %% ABSTRACT PROPERTY REALIZATION (ws.dabs.ni.daqmx.private.DAQmxClass)
    properties (SetAccess=private, Hidden)
        gsPropRegExp =  '.*DAQmxGet(?!(AI|AO|CO|CI|DO|DI|Scale|Sys|Persisted|Cal|Dev|Physical|Switch))(?<varName>.*)\((ulong|uint64),\s*(?<varType>\S*)[\),].*';
        gsPropPrefix = '';
        gsPropIDArgNames = {'taskID'};
        gsPropNumStringIDArgs=0;
    end
    
    %% PDEP PROPERTIES
    %DAQmx-defined properties explicitly added to task, because they are commonly used. Remaining properties are added dynamically, based on demand.
    properties (GetObservable, SetObservable)
        sampQuantSampMode;
        sampQuantSampPerChan;
        sampTimingType;
        
        sampClkRate;
        sampClkSrc;
        
        startTrigType;
        refTrigType;
        pauseTrigType;
    end
    
    %% PUBLIC PROPERTIES
    properties
        taskName; %Unique name (string) for this instance
        
        everyNSamples=[]; %Number of samples to input/output prior to generating EveryNSamples event, to which callbacks can respond
        everyNSamplesEventCallbacks={}; %Cell array of callback function handles to invoke (in order) upon everyNSamples events. Like typical Matlab arguments, the callback must take/expect 2 arguments -- source and event. The source contains the Task object handle. Event is an empty array (unused).
        everyNSamplesReadDataEnable=false; %Logical indicating whether acquired data is read automatically and supplied to callback as part of event data structure.
        everyNSamplesReadDataTypeOption = ''; %String specifying read data type option. If empty, default is used. For analog inputs, options are {'native' 'scaled'}. For digital inputs, options are {'double' 'logical' 'uint8' 'uint16' 'uint32'}. For counter inputs, options are {'double' 'uint32'}.
        everyNSamplesReadTimeOut = inf; %Time to allow for read operations before giving up

        %everyNSamplesEventCallbackDataStructs={}; %Cell array of structures to pass to callbacks for everyNSamples event
        
        doneEventCallbacks={}; %Cell array of callback names to invoke (in order) upon Done event
        %doneEventCallbackDataStructs={}; %Cell array of structures to pass to callbacks for Done event
        
        signalID=''; %One of {'DAQmx_Val_SampleClock', 'DAQmx_Val_SampleCompleteEvent', 'DAQmx_Val_ChangeDetectionEvent', 'DAQmx_Val_CounterOutputEvent'}, indicating which type of signal event is registered for specified signalEventCallbacks.
        signalEventCallbacks={}; %Cell array of callback names to invoke (in order) upon Signal events
        %signalEventCallbackDataStructs={}; %Cell array of structures to pass to callbacks for Signal events
        
        verbose=false; %Logical value indicating, if true, to display additional status/warning information to command line
    end  
    
    %% PROTECTED/PRIVATE PROPERTIES
    properties (Hidden)
        %These are hidden, rather than private, to allow for access by MEX functions. Should be considered private.
        
        %These properties are stored as part of Task, to allow for ready access by MEX function during read/write operations.
        rawDataArrayAI=[]; %Scalar array of the class which the device(s) associated with this Task use for their Analog Input raw data. There can be only one. Empty array indicates freshly constructed.
        rawDataArrayAO=[]; %Scalar array of the class which the device(s) associated with this Task use for their Analog Output raw data. There can be only one. Empty array indicates freshly constructed.
        isLineBasedDigital; %Logical indicating whether Channel(s) in this DI/DO Task are line-based (all Channel(s) must either be line-based or port-based)
        
        %Properties for DAQmx events and their corresponding MATLAB callbacks
        everyNSamplesReadDataClass;
        %         everyNSamplesEventReadDataIndex=0; %Index indicating on which callback to automatically read data prior to callback execution. Value of 0 indicates not to read data.
        %         everyNSamplesEventReadDataOptions=struct.empty(); %Structure of options pertaining to read data operation
        
    end
    
    properties (SetAccess=private)
        taskID;  %A unique integer identifying this Task object (maintains a count of Tasks)
    end
    
    properties (SetAccess=private, Dependent)
        taskType=''; %Member of {'AnalogInput', 'AnalogOutput', 'DigitalInput', 'DigitalOutput', 'CounterInput', 'CounterOutput'}
        deviceNames; %Cell array of device names (though in most cases, there's only one device per task)
        channels; %Array of Channel objects associated with this Task  %TMW: This indirection is used to allow a property to be publically gettable, but only settable by 'friends' or package-mates. Would prefer some native 'package scope' concept.
        %startTriggerSource; %TODO: Get startTriggerSource by determining type, if any, of start trigger
        %refTriggerSource; %TODO: Get refTriggerSource by determining type, if any, of reference trigger
    end
    
    properties (SetAccess=private, Hidden)
        everyNSamplesEventRegisteredFlag=false;
        doneEventRegisteredFlag=false
        signalEventRegisteredFlag=false;
        
        signalIDHidden; %Used by RegisterSignalEvent MEX function        
    end
    
    properties (SetAccess=private, Dependent, Hidden)
        devices; %Array of device objects (though in most cases, there's only one device per task). Property is hidden as 'deviceNames' is recommended way to access Device objects.
    end
    
    %Hidden properties, to allow access by class package-mates TMW: Might prefer some native 'package scope' concept
    properties (Hidden)
        deviceNamesHidden = {};
        channelsHidden;
        taskTypeHidden;
    end
    
    %Private properties
    properties (GetAccess=private, Constant)
        memoryErrorCode = -50352; %Error: 'NI Platform Services:  The requested memory could not be allocated.'
    end
    
    %% PUBLIC METHODS    
    methods
        
        %% TASK CONSTRUCTION/DESTRUCTION
        function obj = Task(varargin)
            % obj = Task(taskName)
            % taskName: (OPTIONAL) A unique string identifying Task. If not supplied, a default name will be generated. 
           
            
            % Note. The current strategy of auto-taskName generation has a
            % very slight risk of running into a problem as follows.
            % Suppose a user provides a taskname like 'Task 123' that
            % matches the format of the auto-generated names. In this case,
            % the current code will have trouble when the auto-generated
            % IDs come to 123.
            
            %Handle case where superclass construction was aborted
            if obj.cancelConstruct
                delete(obj);
                return;
            end
            
            % create/validate taskName
            if nargin == 0
                newtaskID = lclGetNumber();
                tName = ['Task ' num2str(newtaskID)];
            else
                tName = varargin{1};
                if ~ischar(tName) || isempty(strtrim(tName))
                    error('Invalid task name.');
                end
            end
            
            taskmap = ws.dabs.ni.daqmx.Task.getTaskMap();
            
            if taskmap.isKey(tName)
                %NOTE: Could consider returning the already-existing Task, but an error is probably better choice given typical usage
                obj.cancelConstruct = true;
                error('A Task with name ''%s'' already exists in the DAQmx System',tName);
            end
            
            % Set up the new task
            obj.taskName = tName;
            [~, obj.taskID] = obj.apiCall('DAQmxCreateTask',obj.taskName,0);
            dummystr = repmat('a',1,128);
            daqmxName = obj.apiCall('DAQmxGetTaskName',obj.taskID,dummystr,128);
            if ~strcmp(tName,daqmxName)
                warning(['DAQmx has chosen to override your taskname with the name ''' daqmxName '''.']); %#ok<WNTAG>
                obj.taskName = daqmxName;
            end
            taskmap(obj.taskName) = obj; %#ok<NASGU>            

        end
        
        function delete(obj)
            if ~obj.cancelConstruct
                %fprintf('Task::delete()\n');
                try
                    % abort if task is not done
                    if ~obj.isTaskDoneQuiet()
                        obj.abort();
                    end        
                catch me %#ok<NASGU>
                    % If this fails for whatever reason, want to just proceed
                    % In certain error states, isTaskDoneQuiet() can throw,
                    % and we don't want to let that stop us from clearing
                    % the DAQmx task.
                end
                
                %Unregister any callbacks -- required to clear data record in the RegisterXXXCallback MEX functions
                obj.registerDoneEvent();
                obj.registerSignalEvent(); 
                obj.registerEveryNSamplesEvent();

                if ~isempty(obj.channels)
                    deleteHidden(obj.channels);
                end
                
                if ~isempty(obj.taskID)
                    % if a task has a valid taskID, it was successfully
                    % constructed and added to DAQmx
                    obj.apiCall('DAQmxClearTask',obj.taskID);
                end
                
                taskmap = ws.dabs.ni.daqmx.Task.getTaskMap();
                if taskmap.isKey(obj.taskName)
                    taskmap.remove(obj.taskName);
                end
            end
        end        
        
        %% TASK CONTROL
        function start(obj)
            %Transitions the task from the committed state to the running state, which begins measurement or generation.
            %VECTORIZED
            
            for i=1:length(obj)
                obj(i).apiCall('DAQmxStartTask', obj(i).taskID);
            end
        end
        
        function stop(obj)
            %Stops the task and returns it to the state it was in before you called DAQmxStartTask or called an NI-DAQmx Write function with autoStart set to TRUE.
            %VECTORIZED
            
            % Filter Error  -200018: "DAC conversion attempted before data to be converted was available". Not relevant on stop.

            for i=1:length(obj)
                obj(i).apiCallFiltered('DAQmxStopTask',[-200621 -200018], obj(i).taskID);
            end
        end
        
        function abort(obj)
            %Identical to stop(), but should be used to abort ongoing Finite acquisitions/generations.
            %Unlike stop(), irrelevant DAQmx Warnings & Errors are suppressed:
            %  Warning 200010: Occurs when stop() is called to terminate a Finite acquisition/generation prior to the specified number of samples.
            %VECTORIZED
            
            % Filter Error  -200018: "DAC conversion attempted before data to be converted was available". Not relevant on abort.            
            for i=1:length(obj)
                obj(i).apiCallFiltered('DAQmxStopTask',[200010 -200621 -200018], obj(i).taskID);
            end
        end
        
        function tf = isTaskDone(obj)
            %Queries the status of the task and indicates if it completed execution. Use this function to ensure that the specified operation is complete before you stop the task.
            %VECTORIZED
            
            tf = false(size(obj));
            for c = 1:numel(obj)
                tf(c) = obj(c).apiCall('DAQmxIsTaskDone',obj(c).taskID,0);
            end
        end
        
        function tf = isTaskDoneQuiet(obj)
            %Queries the status of the task and indicates if it completed execution. Use this function to ensure that the specified operation is complete before you stop the task.
            %Unlike isTaskDone(), DAQmx Warning 200010 is suppressed. This warning occurs when Task was stopped (aborted) during a Finite Acquisition/Generation.
            %VECTORIZED
            
            tf = false(size(obj));
            for c = 1:numel(obj)
                tf(c) = obj(c).apiCallFiltered('DAQmxIsTaskDone',[200010 -200621], obj(c).taskID,0);
            end
        end
        
        function waitUntilTaskDone(obj,timeToWait)
            %Waits for the measurement or generation to complete. Use this function to ensure that the specified operation is complete before you stop the task.
            %VECTORIZED
            %
            %function waitUntilTaskDone(obj,timeToWait)
            %   timeToWait: The maximum amount of time, in seconds, to wait for the measurement or generation to complete. The function returns an error if the time elapses before the measurement or generation is complete.
            %               A value of -1 or Inf means to wait indefinitely.
            %               If you set timeToWait to 0, the function checks once and returns an error if the measurement or generation is not done.
            %
            
            if nargin < 2 || isempty(timeToWait) || isinf(timeToWait)
                timeToWait = -1;
            end
            
            for i=1:length(obj)
                obj(i).apiCall('DAQmxWaitUntilTaskDone',obj(i).taskID, timeToWait);
            end
        end
        
        function clear(obj)
            %TODO: Consider renaming this to 'remove', or similar, to avoid
            %confusion with MATLAB builtin 'clear' Clears the task. Before
            %clearing, this function stops the task, if necessary, and
            %releases any resources reserved by the task. You cannot use a
            %task once you clear the task without recreating or reloading
            %the task. If you use the DAQmxCreateTask function or any of
            %the NI-DAQmx Create Channel functions within a loop, use this
            %function within the loop after you finish with the task to
            %avoid allocating unnecessary memory
            %VECTORIZED
            
            delete(obj);
        end
        
        function control(obj,state)
            %Alters the state of a task according to the action you specify. To minimize the time required to start a task, for example, DAQmxTaskControl can commit the task prior to starting.
            %function control(obj,state)
            %   state: Member of {'DAQmx_Val_Task_Start' 'DAQmx_Val_Task_Stop' 'DAQmx_Val_Task_Verify' 'DAQmx_Val_Task_Commit' 'DAQmx_Val_Task_Reserve' 'DAQmx_Val_Task_Unreserve' 'DAQmx_Val_Task_Abort'}
            %VECTORIZED
            
            for i=1:length(obj)
                obj(i).apiCall('DAQmxTaskControl', obj(i).taskID, obj(i).encodePropVal(state));
            end
        end
        
        %% EVENTS
        function registerEveryNSamplesEvent(obj, callbackFunc, everyNSamples,readDataEnable, readDataTypeOption)
            %Registers or unregisters a callback function to receive an event when the specified number of samples is written from the device to the buffer or from the buffer to the device. This function only works with devices that support buffered tasks.
            %When you stop a task explicitly any pending events are discarded. For example, if you call DAQmxStopTask then you do not receive any pending events.
            %   
            %function registerEveryNSamplesEvent(obj, callbackFunc, everyNSamples,readDataEnable, readDataTypeOption)
            %  callbackFunc: Function handle identifying single callback to set as the 'everyNSamplesEventCallbacks' property. This single callback will be invoked upon the everyNSamples event. If empty, any previously registered event is unregistered.
            %  everyNSamples:  Number to set 'everyNSamples' property to, which specifies number of samples to acquire/output before EveryNSamples event is generated. Argument can be omitted if the 'everyNSamples' property has already been set.
            %  readDataEnable: If specified, sets the 'everyNSamplesReadDataEnable' property.
            %  readDataTypeOption: If specified, sets the 'everyNSamplesReadDataTypeOption' property. 
            %                       
            %NOTE: Method arguments differ in several ways from DAQmxRegisterEveryNSampleEvent()
            %NOTE: This method is effectively a macro to set the the everyNSamplesEventCallbacks/everyNSamples and related properties in tandem used to bind one and only one callback function to the EveryNSamples event, analagous to DAQmxRegisterEveryNSamplesEvent().
            %NOTE: To bind multiple callbacks in a specified order, then the everyNSamplesEventCallbacks and everyNSamples properties must be set directly.

            
            %Unregister first
            obj.unregisterXXXEventPriv('everyNSamples','RegisterEveryNCallback');
            
            %Set each of the non-callback properties
            if nargin >=3 && ~isempty(everyNSamples)
                obj.everyNSamples = everyNSamples;
            end
            
            if nargin >=4 && ~isempty(readDataEnable)
                obj.everyNSamplesReadDataEnable = readDataEnable;
            end
            
            if nargin >=5 && ~isempty(readDataTypeOption)
                obj.everyNSamplesReadDataTypeOption = readDataTypeOption;
            end
            
            %Set the callback property
            %No need to explicitly register here .. this occurs via setting the properties!
            if nargin >= 2
                obj.everyNSamplesEventCallbacks = callbackFunc;
            end
                

        end
        
        function registerDoneEvent(obj, callbackFunc)
            %Registers a callback function to receive an event when the specified number of samples is written from the device to the buffer or from the buffer to the device. This function only works with devices that support buffered tasks.
            %When you stop a task explicitly any pending events are discarded. For example, if you call DAQmxStopTask then you do not receive any pending events.
            %NOTE: Method arguments differ in several ways from DAQmxRegisterDoneEvent()
            %NOTE: This method is equivalent to setting the doneEventCallbacks property to a cell array of one and only one function, given by callbackFunc
            %NOTE: To bind multiple callbacks in a specified order, then the doneEventCallbacks property must be set directly.
            %
            %function registerDoneEvent(obj, callbackName)
            %  callbackFunc: Function handle identifying single callback to set as the 'doneEventCallbacks' property, which specifies a list of callbacks to invoke, in order, upon the Done event.
            
            
            if nargin == 1
                obj.unregisterXXXEventPriv('done','RegisterDoneCallback');
            else
                try  %TODO: This try/catch is likely unnecessary, the set access method should handle this
                    obj.doneEventCallbacks = callbackFunc;
                catch ME
                    obj.doneEventCallbacks = {};
                    ME.rethrow();
                end
            end
            
            %No need to explicitly register here .. this occurs via setting the properties!
        end                     
                
        function registerSignalEvent(obj, callbackFunc, signalID)
            
            %%%%%%%%%%%TODO%%%%%%%%
            %Registers a callback function to receive an event when the specified hardware event occurs. When you stop a task explicitly any pending events are discarded. For example, if you call stop() then you do not receive any pending events.
            %The signalID must be set at time of this call and cannot be changed (event must be unregistered/re-registered to change). The callbackName can be set before, during, or after time of registration, via signalEventCallbacks property.
            %NOTE: Method arguments differ in several ways from DAQmxRegisterSignalEvent()
            
            %Registers a callback function to receive an event when the specified number of samples is written from the device to the buffer or from the buffer to the device. This function only works with devices that support buffered tasks.
            %When you stop a task explicitly any pending events are discarded. For example, if you call DAQmxStopTask then you do not receive any pending events.
            %NOTE: Method arguments differ in several ways from DAQmxRegisterDoneEvent()
            %NOTE: This method is equivalent to setting the doneEventCallbacks property to a cell array of one and only one function, given by callbackFunc
            %NOTE: To bind multiple callbacks in a specified order, then the doneEventCallbacks property must be set directly.
            %
            %function registerDoneEvent(obj, callbackName)
            %  callbackFunc: Function handle identifying single callback to set as the 'doneEventCallbacks' property, which specifies a list of callbacks to invoke, in order, upon the Done event.
            %%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if nargin == 1
                obj.unregisterXXXEventPriv('signal','RegisterSignalCallback');
            elseif nargin < 3
                error('Cannot register Signal Event without specifying both callback function and signalID value');
            else %The callbackFunc and everyNSamples must be specified here
                obj.signalID = ''; %This will unregister if needed, to prevent double registration
                try %TODO: This try/catch is likely unnecessary, the set access method should handle this
                    obj.signalEventCallbacks = callbackFunc;
                catch ME
                    obj.signalEventCallbacks = {};
                    ME.rethrow();
                end
                obj.signalID = signalID;
            end            
            
            %No need to explicitly register here .. this occurs via setting the properties!
            
        end               
        
        
        %% CHANNEL CONFIGURATION/CREATION
        
        function chanObjs = createAIVoltageChan(obj,deviceNames,chanIDs,chanNames,minVal,maxVal,units,customScaleName,terminalConfig)
            %Creates channel(s) to measure voltage and adds the channel(s) to the Task. If your measurement requires the use of internal excitation or you need the voltage to be scaled by excitation, call createAIVoltageChanWithExcit()
            %
            %%function chanObjs = createAIVoltageChan(obj,deviceNames,chanIDs,chanNames,minVal,maxVal,units,customScaleName,terminalConfig)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of channel IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: (OPTIONAL) A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   minVal: (OPTIONAL) The minimum value, in units, that you expect to measure. If omitted/blank, then largest possible range supported by device is used.
            %   maxVal: (OPTIONAL) The maximum value, in units, that you expect to measure. If omitted/blank, then largest possible range supported by device is used.
            %   units: (OPTIONAL) One of {'DAQmx_Val_Volts', 'DAQmx_Val_FromCustomScale'}. Specifies units to use to return the voltage measurements. 'DAQmx_Val_FromCustomScale' specifies that units of a supplied scale are to be used (see 'units' argument). If blank/omitted, default is 'DAQmx_Val_Volts'.
            %   customScaleName: (OPTIONAL) The name of a custom scale to apply to the channel. To use this parameter, you must set units to 'DAQmx_Val_FromCustomScale'. If you do not set units to DAQmx_Val_FromCustomScale, this argument is ignored.
            %   terminalConfig: (OPTIONAL) One of {'DAQmx_Val_Cfg_Default', 'DAQmx_Val_RSE', 'DAQmx_Val_NRSE', 'DAQmx_Val_Diff', 'DAQmx_Val_PseudoDiff'}. Specifies the input terminal configuration for the channel. If omitted/blank, 'DAQmx_Val_Cfg_Default' is used, NI-DAQmx to choose the default terminal configuration for the channel.
            %
            %   chanObjs: The created Channel object(s)
            
            %Create default arguments, as needed
            if nargin < 4 || isempty(chanNames)
                chanNames = '';
            end
            
            if (nargin < 5 || isempty(minVal)) || (nargin < 6 || isempty(maxVal))
                %Get voltage min/max.
                maxArrayLength = 100;
                [deviceNames, voltageRangeArray] = obj.apiCall('DAQmxGetDevAIVoltageRngs', deviceNames, zeros(maxArrayLength,1), maxArrayLength);
                
                %Choose the range which maximizes the total range by default.
                rangeSpans = voltageRangeArray(2:2:end) - voltageRangeArray(1:2:end);
                [~, maxRangeSpanIdx] = max(rangeSpans);
                
                if (nargin < 5 || isempty(minVal))
                    minVal = voltageRangeArray(2*maxRangeSpanIdx-1);
                end
                if (nargin < 6 || isempty(maxVal))
                    maxVal = voltageRangeArray(2*maxRangeSpanIdx);
                end
            end
            
            if nargin < 7 || isempty(units)
                units = 'DAQmx_Val_Volts';
            end
            
            if strcmpi(units,'DAQmx_Val_Volts')
                customScaleName = libpointer(); %Ignores any supplied argument
            elseif strcmpi(units,'DAQmx_Val_FromCustomScale') && (nargin < 8 || isempty(customScaleName) || ~ischar(customScaleName))
                error('A ''customScaleName'' must be supplied when ''units'' is specified as ''DAQmx_Val_FromCustomScale''');
            end
            
            if nargin < 9
                terminalConfig = 'DAQmx_Val_Cfg_Default';
            end
            
            %Create the channel(s)!
            chanObjs = ws.dabs.ni.daqmx.AIChan('DAQmxCreateAIVoltageChan',obj,deviceNames,chanIDs,chanNames,...
                obj.encodePropVal(terminalConfig),minVal,maxVal,obj.encodePropVal(units),customScaleName);
            
            
        end
        
        
        function chanObjs = createAOVoltageChan(obj,deviceNames,chanIDs,chanNames,minVal,maxVal,units,customScaleName)
            %Creates channel(s) to generate voltage and adds the channel(s) to the Task.
            %
            %%function chanObjs = createAIVoltageChan(obj,deviceNames,chanIDs,chanNames,minVal,maxVal,units,customScaleName,terminalConfig)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of channel IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: (OPTIONAL) A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   minVal: (OPTIONAL) The minimum value, in units, that you expect to generate. If omitted/blank, then largest possible range supported by device is used.
            %   maxVal: (OPTIONAL) The maximum value, in units, that you expect to generate. If omitted/blank, then largest possible range supported by device is used.
            %   units: (OPTIONAL) One of {'DAQmx_Val_Volts', 'DAQmx_Val_FromCustomScale'}. Specifies units in which to generate voltage. 'DAQmx_Val_FromCustomScale' specifies that units of a supplied scale are to be used (see 'units' argument). If blank/omitted, default is 'DAQmx_Val_Volts'.
            %   customScaleName: (OPTIONAL) The name of a custom scale to apply to the channel. To use this parameter, you must set units to 'DAQmx_Val_FromCustomScale'. If you do not set units to DAQmx_Val_FromCustomScale, this argument is ignored.
            %
            %   chanObjs: The created Channel object(s)
            
            %Create default arguments, as needed
            if nargin < 4 || isempty(chanNames)
                chanNames = '';
            end
            
            if (nargin < 5 || isempty(minVal)) || (nargin < 6 || isempty(maxVal))
                %Get voltage min/max.
                maxArrayLength = 100;
                [deviceNames, voltageRangeArray] = obj.apiCall('DAQmxGetDevAOVoltageRngs', deviceNames, zeros(maxArrayLength,1), maxArrayLength);
                
                %Choose the range which maximizes the total range by default.
                rangeSpans = voltageRangeArray(2:2:end) - voltageRangeArray(1:2:end);
                [~, maxRangeSpanIdx] = max(rangeSpans);
                
                if (nargin < 5 || isempty(minVal))
                    minVal = voltageRangeArray(2*maxRangeSpanIdx-1);
                end
                if (nargin < 6 || isempty(maxVal))
                    maxVal = voltageRangeArray(2*maxRangeSpanIdx);
                end
            end
            
            if nargin < 7 || isempty(units)
                units = 'DAQmx_Val_Volts';
            end
            
            if strcmpi(units,'DAQmx_Val_Volts')
                customScaleName = libpointer(); %Ignores any supplied argument
            elseif strcmpi(units,'DAQmx_Val_FromCustomScale') && (nargin < 8 || isempty(customScaleName) || ~ischar(customScaleName))
                error('A ''customScaleName'' must be supplied when ''units'' is specified as ''DAQmx_Val_FromCustomScale''');
            end
            
            
            %Create the channel(s)!
            chanObjs = ws.dabs.ni.daqmx.AOChan('DAQmxCreateAOVoltageChan',obj,deviceNames,chanIDs,chanNames,...
                minVal,maxVal,obj.encodePropVal(units),customScaleName);
            
            
        end
        
        function chanObj = createDOChan(obj,deviceNames,chanIDs,chanNames,lineGrouping)
            %Creates channel(s) to generate digital signals and adds the channel(s) to the task you specify with taskHandle. You can group digital lines into one digital channel or separate them into multiple digital channels.
            %If you specify one or more entire ports in lines by using port physical channel names, you cannot separate the ports into multiple channels. To separate ports into multiple channels, use this function multiple times with a different port each time.
            %
            %%function chanObj = addDigitalOutputChannel(obj,deviceNames,chanIDs,chanNames)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A string identifying port and/or line IDs for this Channel, e.g. 'port0','port0/line0:1', or 'line0:15'. In the case of multiple deviceNames (a multi-device Task), a cell array of such strings
            %   chanNames: (OPTIONAL) A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   lineGrouping: (OPTIONAL) One of {'DAQmx_Val_ChanPerLine', 'DAQmx_Val_ChanForAllLines'}. If empty/omitted, 'DAQmx_Val_ChanForAllLines' is used. Specifies whether to group digital lines into one or more virtual channels. If you specify one or more entire ports in chanIDs, you must set lineGrouping to DAQmx_Val_ChanForAllLines.
            %
            %   chanObj: The created Channel object
            
            % TODO
            %   * Support comma-separated list specification of multiple physical channels. In doing so, deal with coercion: if any of the channels is port-based, then all are forced to be port-based, even if containing the string 'line'.
            %   * Create separate createDXChan() methods specifically for port and line-based channels, with numeric specification.
            %   * At moment, the 'DAQmx_Val_ChanPerLine' option is /not/ working!
            
            %Supply default input arguments, as needed
            if nargin < 4
                chanNames = '';
            end
            
            if nargin < 5
                lineGrouping = 'DAQmx_Val_ChanForAllLines';
            end
            
            %Create the channel!
            chanObj = ws.dabs.ni.daqmx.DOChan('DAQmxCreateDOChan',obj,deviceNames,chanIDs,chanNames,obj.encodePropVal(lineGrouping));
        end
        
        
        function chanObj = createDIChan(obj,deviceNames,chanIDs,chanNames,lineGrouping)
            %Creates channel(s) to measure digital signals and adds the channel(s) to the task you specify with taskHandle. 
            %You can group digital lines into one digital channel or separate them into multiple digital channels. 
            %If you specify one or more entire ports in lines by using port physical channel names, you cannot separate the ports into multiple channels.
            %To separate ports into multiple channels, use this function multiple times with a different port each time.
            %
            %%function chanObj = createDIChan(obj,deviceNames,chanIDs,chanNames,lineGrouping)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A string identifying port and/or line IDs for this Channel, e.g. 'port0','port1:2', 'port0/line0:1', or 'line0:15'. In the case of multiple deviceNames (a multi-device Task), a cell array of such strings
            %       If port name is ommitted, port0 is assumed. 
            %       At this time, unlike DAQmx function, you cannot specify a comma-separated list, e.g. of lines on different ports, for the channel specification
            %       The Channel(s) added by this method are either 'line-based' or 'port-based':
            %           If the string 'line' is part of the chanIDs value specified, the channel(s) added are line-based. 
            %           Otherwise, the channel added is port-based (note that lineGrouping='DAQmx_Val_ChanForAllLines' is mandatory in this case)
            %
            %   chanNames: <OPTIONAL> A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   lineGrouping: <OPTIONAL - one of {'DAQmx_Val_ChanPerLine', 'DAQmx_Val_ChanForAllLines'} - Default: DAQmx_Val_ChanForAllLines> Specifies whether to group digital lines into one or more virtual channels. If you specify one or more entire ports in chanIDs (i.e. 'port-based'), you must set lineGrouping to DAQmx_Val_ChanForAllLines.
            %
            %   chanObj: The created Channel object
            %
                   
            % TODO
            %   * Support comma-separated list specification of multiple physical channels. In doing so, deal with coercion: if any of the channels is port-based, then all are forced to be port-based, even if containing the string 'line'.
            %   * Create separate createDXChan() methods specifically for port and line-based channels, with numeric specification.
            %   * At moment, the 'DAQmx_Val_ChanPerLine' option is /not/ working!
            
            %Supply default input arguments, as needed
            if nargin < 4
                chanNames = '';
            end
            
            if nargin < 5
                lineGrouping = 'DAQmx_Val_ChanForAllLines';
            end            
                       
            %Create the channel(s)!
            chanObj = ws.dabs.ni.daqmx.DIChan('DAQmxCreateDIChan',obj,deviceNames,chanIDs,chanNames,obj.encodePropVal(lineGrouping));                        

        end
        
        
        function chanObjs = createCOPulseChanFreq(obj, deviceNames, chanIDs, chanNames, freq, dutyCycle, initialDelay, idleState, units)
            %Creates channel(s) to generate digital pulses that freq and dutyCycle define and adds the channel to the task you specify with taskHandle.
            %The pulses appear on the default output terminal of the counter unless you select a different output terminal (by setting the OutputTerminal property after creating the Channel)
            %NOTE: Multiple CO channels can be created with this call, but they will have same frequency, dutyCycle, initialDelay, idleState, and units.
            %
            %function chanObj = createCOPulseChanFreq(obj, deviceName, chanIDs, chanNames, freq, dutyCycle, initialDelay, idleState, units)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of channel IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: (OPTIONAL) A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   freq: The frequency at which to generate pulses.
            %   dutyCycle: (OPTIONAL) The width of the pulse divided by the pulse period. NI-DAQmx uses this ratio, combined with frequency, to determine pulse width and the interval between pulses. If omitted/empty, value of 0.5 used.
            %   initialDelay: (OPTIONAL) The amount of time in seconds to wait before generating the first pulse. If omitted/empty, value of 0 is used.
            %   idleState: (OPTIONAL) One of {'DAQmx_Val_High', 'DAQmx_Val_Low'}. The resting state of the output terminal. If omitted/empty, 'DAQmx_Val_Low' is used.
            %   units: (OPTIONAL) One of {'DAQmx_Val_Hz'}. The units in which to specify freq. If omitted/empty, default value of 'DAQmx_Val_Hz' is used.
            %
            %   chanObjs: The created Channel object(s)
            
            %Create default arguments, as needed
            if nargin < 5
                error('Insufficient number of input arguments.');
            end
            
            if isempty(chanNames)
                chanNames = '';
            end
            
            if nargin < 6 || isempty(dutyCycle)
                dutyCycle = 0.5;
            end
            
            if nargin < 7 || isempty(initialDelay)
                initialDelay = 0.0;
            end
            
            if nargin < 8 || isempty(idleState)
                idleState = 'DAQmx_Val_Low';
            end
            
            if nargin < 9 || isempty(units)
                units = 'DAQmx_Val_Hz';
            end
            
            %Create the channel!
            chanObjs = ws.dabs.ni.daqmx.COChan('DAQmxCreateCOPulseChanFreq',obj,deviceNames,chanIDs,chanNames,...
                obj.encodePropVal(units), obj.encodePropVal(idleState), initialDelay, freq, dutyCycle);
        end
        
        
        function chanObjs = createCOPulseChanTicks(obj, deviceNames, chanIDs, chanNames, sourceTerminal, lowTicks, highTicks, initialDelay, idleState)
            %Creates channel(s) to generate digital pulses defined by the number of timebase ticks that the pulse is at a high state and the number of timebase ticks that the pulse is at a low state and also adds the channel to the task you specify with taskHandle.
            %The pulses appear on the default output terminal of the counter unless you select a different output terminal.
            %NOTE: Multiple CO channels can be created with this call, but they will have same lowTicks, highTicks, sourceTerminal, initialDelay, and idleState.
            %
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of channel IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: (OPTIONAL) A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   lowTicks: The number of timebase ticks that the pulse is low.
            %   sourceTerminal: The terminal to which you connect an external timebase. The terminal will have  You also can specify a source terminal by using a terminal name.
            %   highTicks: The number of timebase ticks that the pulse is high.
            %   initialDelay: <OPTIONAL - Default=0> The number of timebase ticks to wait before generating the first pulse.
            %   idleState: <OPTIONAL - Default='DAQmx_Val_Low'> One of {'DAQmx_Val_High', 'DAQmx_Val_Low'}. The resting state of the output terminal.
            %
            %   chanObjs: The created Channel object(s)
            
            %Create default arguments, as needed
            if nargin < 7
                error('Insufficient number of input arguments.');
            end
            
            if isempty(chanNames)
                chanNames = '';
            end
            
            if nargin < 8 || isempty(initialDelay)
                initialDelay = 0.0;
            end
            
            if nargin < 9 || isempty(idleState)
                idleState = 'DAQmx_Val_Low';
            end
            
            %Create the channel!
            chanObjs = ws.dabs.ni.daqmx.COChan('DAQmxCreateCOPulseChanTicks',obj,deviceNames,chanIDs,chanNames,...
                sourceTerminal, obj.encodePropVal(idleState), initialDelay, lowTicks, highTicks);
        end
        
        function chanObjs = createCOPulseChanTime(obj, deviceNames, chanIDs, chanNames, lowTime, highTime, initialDelay, idleState, units)
            %Creates channel(s) to generate digital pulses defined by the number of timebase ticks that the pulse is at a high state and the number of timebase ticks that the pulse is at a low state and also adds the channel to the task you specify with taskHandle.
            %The pulses appear on the default output terminal of the counter unless you select a different output terminal.
            %NOTE: Multiple CO channels can be created with this call, but they will have same lowTicks, highTicks, sourceTerminal, initialDelay, and idleState.
            %
            %function chanObj = createCOPulseChanTicks(obj, deviceName, chanIDs, chanNames, freq, dutyCycle, initialDelay, idleState, units)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of channel IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: <OPTIONAL> A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   lowTime: The amount of time the pulse is low, in seconds.
            %   highTime: The amount of time the pulse is high, in seconds.
            %   initialDelay: <OPTIONAL - Default: 0> The amount of time in seconds to wait before generating the first pulse.
            %   idleState: <OPTIONAL - Default: 'DAQmx_Val_Low'> One of {'DAQmx_Val_High', 'DAQmx_Val_Low'}. The resting state of the output terminal.
            %   units: <OPTIONAL - Default: 'DAQmx_Val_Seconds'> One of {'DAQmx_Val_Seconds'}. The units in which to specify time.
            %
            %   chanObjs: The created Channel object(s)
            
            %Create default arguments, as needed
            if nargin < 6
                error('Insufficient number of input arguments.');
            end
            
            if isempty(chanNames)
                chanNames = '';
            end
            
            if nargin < 7 || isempty(initialDelay)
                initialDelay = 0.0;
            end
            
            if nargin < 8 || isempty(idleState)
                idleState = 'DAQmx_Val_Low';
            end
            
            if nargin < 9 || isempty(units)
                units = 'DAQmx_Val_Seconds';
            end
            
            
            %Create the channel!
            chanObjs = ws.dabs.ni.daqmx.COChan('DAQmxCreateCOPulseChanTime',obj,deviceNames,chanIDs,chanNames,...
                obj.encodePropVal(units), obj.encodePropVal(idleState), initialDelay, lowTime, highTime);
        end
        
        
        
        
        
        
        
        function chanObjs = createCICountEdgesChan(obj, deviceNames, chanIDs, chanNames, countDirection, edge, initialCount)
            %Creates a channel to count the number of rising or falling edges of a digital signal and adds the channel to the task you specify with taskHandle.
            %You can create only one counter input channel at a time with this function because a task can include only one counter input channel.
            %To read from multiple counters simultaneously, use a separate task for each counter. Connect the input signal to the default input terminal of the counter unless you select a different input terminal.
            %
            %function chanObj = createCICountEdgesChan(obj, deviceName, chanIDs, chanNames, freq, dutyCycle, initialDelay, idleState, units)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of counter IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: (OPTIONAL) A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   countDirection: (OPTIONAL) One of {'DAQmx_Val_CountUp', 'DAQmx_Val_CountDown', 'DAQmx_Val_ExtControlled'}. If empty/omitted, 'DAQmx_Val_CountUp' is assumed. Specifies whether to increment or decrement the counter on each edge.
            %   edge: (OPTIONAL) One of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}. If empty/omitted, 'DAQmx_Val_Rising' is assumed. Specifies on which edges of the input signal to increment or decrement the count.
            %   initialCount: (OPTIONAL) The value from which to start counting. If empty/omitted, the value 0 is assumed.
            %
            %   chanObjs: The created Channel object(s)
            
            
            
            %Create default arguments, as needed
            if nargin < 3
                error('Insufficient number of input arguments.');
            end
            
            if nargin < 4 || isempty(chanNames)
                chanNames = '';
            end
            
            if nargin < 5 || isempty(countDirection)
                countDirection = 'DAQmx_Val_CountUp';
            end
            
            if nargin < 6 || isempty(edge)
                edge = 'DAQmx_Val_Rising';
            end
            
            if nargin < 7 || isempty(initialCount)
                initialCount = 0;
            elseif ~isnumeric(initialCount) || initialCount < 0 || round(initialCount) ~= (initialCount)
                error('Argument ''initialCount'' must be non-negative integer value');
            end
            
            %Create the channel!
            chanObjs = ws.dabs.ni.daqmx.CIChan('DAQmxCreateCICountEdgesChan',obj,deviceNames,chanIDs,chanNames,...
                obj.encodePropVal(edge),initialCount, obj.encodePropVal(countDirection));
            
        end
        
        function chanObjs = createCIPeriodChan(obj, deviceNames, chanIDs, chanNames, edge, minVal, maxVal, units, measMethod, measTime, divisor, customScaleName)
            %Creates a channel to measure the period of a digital signal
            %and adds the channel to the task you specify with taskHandle.
            %You can create only one counter input channel at a time with
            %this function because a task can include only one counter
            %input channel. To read from multiple counters simultaneously,
            %use a separate task for each counter. Connect the input signal
            %to the default input terminal of the counter unless you select
            %a different input terminal.
            %            
            % function chanObjs = createCIPeriodChan(obj, deviceNames, chanIDs, chanNames, edge, units, minVal, maxVal, measMethod, measTime, divisor, customScaleName)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of counter IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: <OPTIONAL> A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   edge: <OPTIONAL - Default='DAQmx_Val_Rising'> One of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}. Specifies on which edges of the input signal to increment or decrement the coun
            %   minVal: <OPTIONAL - Default=2e-8s/1 tick> The minimum value, in units, that you expect to measure.
            %   maxVal: <OPTIONAL - Default=42.94s/2^31 ticks> The maximum value, in units, that you expect to measure.
            %   units: <OPTIONAL - Default='DAQmx_Val_Seconds'> One of {'DAQmx_Val_Seconds' 'DAQmx_Val_Ticks' 'DAQmx_Val_FromCustomScale'}. The units to use to return the measurement.
            %   measMethod: <OPTIONAL - Default=DAQmx_Val_LowFreq1Ctr> One of {'DAQmx_Val_LowFreq1Ctr' 'DAQmx_Val_HighFreq2Ctr' 'DAQmx_Val_LargeRange2Ctr'}. Specifies the method used to calculate the frequency or period of the signal.  
            %   measTime: <OPTIONAL - Default=0> The length of time to measure the frequency or period of a digital signal, when measMethod is DAQmx_Val_HighFreq2Ctr. Measurement accuracy increases with increased measurement time and with increased signal frequency.
            %   divisor: <OPTIONAL - Default=1> The value by which to divide the input signal, when measMethod is DAQmx_Val_LargeRng2Ctr. The larger this value, the more accurate the measurement, but too large a value can cause the count register to roll over, resulting in an incorrect measurement.
            %   customScaleName: <OPTIONAL> The name of a custom scale to apply to the channel. To use this parameter, you must set units to 'DAQmx_Val_FromCustomScale'. If you do not set units to DAQmx_Val_FromCustomScale, this argument is ignored.
            %
            % NOTES
            %   For standard 1-counter operation, valid values of minVal/maxVal are based on 1-2^31 timebase ticks, where timebase may be either the 10MHz or 100kHz reference clocks on X series devices

            
            %Create default arguments, as needed
            error(nargchk(3,12,nargin,'struct'));

            if nargin < 4 || isempty(chanNames)
                chanNames = '';
            end
            
            if nargin < 5 || isempty(edge)
                edge = 'DAQmx_Val_Rising';
            end
            
            if nargin < 8 || isempty(units)
                units = 'DAQmx_Val_Seconds';
            end
            
            if nargin < 6 || isempty(minVal)
                switch units
                    case 'DAQmx_Val_Seconds'
                        minVal = 2e-8;
                    case 'DAQmx_Val_Ticks'
                        minVal = 1;
                    otherwise
                        error('With specified ''units'', the ''minVal'' argument must be supplied');
                end
                
            end
            
            if nargin < 7 || isempty(maxVal)
                switch units
                    case 'DAQmx_Val_Seconds'
                        maxVal = 42.94;
                    case 'DAQmx_Val_Ticks'
                        maxVal = 2^31;
                    otherwise
                        error('With specified ''units'', the ''minVal'' argument must be supplied');
                end
            end                                    
            
            if nargin < 9 || isempty(measMethod)
                measMethod = 'DAQmx_Val_LowFreq1Ctr';
            end
            
            if nargin < 10 || isempty(measTime)
                measTime = 0;
            end
            
            if nargin < 11 || isempty(divisor)
                divisor = 1;
            end
            
            if ~strcmpi(units, 'DAQmx_Val_FromCustomScale')
                customScaleName = libpointer(); %Ignores any supplied argument
            elseif (nargin < 12 || isempty(customScaleName) || ~ischar(customScaleName))
                error('A ''customScaleName'' must be supplied when ''units'' is specified as ''DAQmx_Val_FromCustomScale''');
            end
            
            %Create the channel!
            chanObjs = ws.dabs.ni.daqmx.CIChan('DAQmxCreateCIPeriodChan',obj,deviceNames,chanIDs,chanNames,...
                minVal, maxVal, obj.encodePropVal(units), obj.encodePropVal(edge), obj.encodePropVal(measMethod), ...
                measTime, divisor, customScaleName);
            
        end
        
        function chanObjs = createCITwoEdgeSepChan(obj, deviceNames, chanIDs, chanNames, firstEdge, secondEdge, minVal, maxVal, units, customScaleName)
            %Creates a channel that measures the amount of time between the rising or
            %falling edge of one digital signal and the rising or falling edge of
            %another digital signal. You can create only one counter input channel at a
            %time with this function because a task can include only one counter input
            %channel. To read from multiple counters simultaneously, use a separate
            %task for each counter. Connect the input signals to the default input
            %terminals of the counter unless you select different input terminals.
            %
            %SYNTAX
            % function chanObjs = createCITwoEdgeSepChan(obj, deviceNames, chanIDs, chanNames, edge, units, minVal, maxVal, measMethod, measTime, divisor, customScaleName)
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, chanIDs must also be a cell array (of equal length).
            %   chanIDs: A numeric array of counter IDs or, in the case of multiple deviceNames (a multi-device Task), a cell array of such numeric arrays
            %   chanNames: <OPTIONAL> A string or string cell array specifying names to assign to each of the channels in chanIDs (if a single string, the chanID is appended for each channel) In the case of a multi-device Task, a cell array of such strings or string cell arrays. If omitted/empty, then default DAQmx channel name is used.
            %   firstEdge: <OPTIONAL - Default='DAQmx_Val_Rising'> One of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}. Specifies on which edges of the first signal to increment or decrement the coun
            %   secondEdge: <OPTIONAL - Default='DAQmx_Val_Rising'> One of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}. Specifies on which edges of the second signal to increment or decrement the coun
            %   minVal: <OPTIONAL - Default=2e-8s/1 tick> The minimum value, in units, that you expect to measure.
            %   maxVal: <OPTIONAL - Default=42.94s/2^31 ticks> The maximum value, in units, that you expect to measure.
            %   units: <OPTIONAL - Default='DAQmx_Val_Seconds'> One of {'DAQmx_Val_Seconds' 'DAQmx_Val_Ticks' 'DAQmx_Val_FromCustomScale'}. The units to use to return the measurement.
            %   customScaleName: <OPTIONAL> The name of a custom scale to apply to the channel. To use this parameter, you must set units to 'DAQmx_Val_FromCustomScale'. If you do not set units to DAQmx_Val_FromCustomScale, this argument is ignored.
            %
            % NOTES
            %   Valid values of minVal/maxVal are based on 1-2^31 timebase ticks, where timebase may be either the 10MHz or 100kHz reference clocks on X series devices
            %               
                        
            %Create default arguments, as needed
            error(nargchk(3,10,nargin,'struct'));
            
            if nargin < 4 || isempty(chanNames)
                chanNames = '';
            end
            
            if nargin < 5 || isempty(firstEdge)
                firstEdge = 'DAQmx_Val_Rising';
            end
            
                        
            if nargin < 6 || isempty(secondEdge)
                secondEdge = 'DAQmx_Val_Rising';
            end
            
            
            if nargin < 9 || isempty(units)
                units = 'DAQmx_Val_Seconds';
            end
            
            if nargin < 7 || isempty(minVal)
                switch units
                    case 'DAQmx_Val_Seconds'
                        minVal = 2e-8;
                    case 'DAQmx_Val_Ticks'
                        minVal = 1;
                    otherwise
                        error('With specified ''units'', the ''minVal'' argument must be supplied');
                end
                
            end
            
            if nargin < 8 || isempty(maxVal)
                switch units
                    case 'DAQmx_Val_Seconds'
                        maxVal = 42.94;
                    case 'DAQmx_Val_Ticks'
                        maxVal = 2^31;
                    otherwise
                        error('With specified ''units'', the ''minVal'' argument must be supplied');
                end
            end
                        
            if ~strcmpi(units, 'DAQmx_Val_FromCustomScale')
                customScaleName = libpointer(); %Ignores any supplied argument
            elseif (nargin < 12 || isempty(customScaleName) || ~ischar(customScaleName))
                error('A ''customScaleName'' must be supplied when ''units'' is specified as ''DAQmx_Val_FromCustomScale''');
            end
            
            %Create the channel!
            chanObjs = ws.dabs.ni.daqmx.CIChan('DAQmxCreateCITwoEdgeSepChan',obj,deviceNames,chanIDs,chanNames,...
                minVal, maxVal, obj.encodePropVal(units), obj.encodePropVal(firstEdge), obj.encodePropVal(secondEdge), ...
                customScaleName);
            
        end
        
        
        
        %% TIMING
        function cfgSampClkTiming(obj, rate, sampleMode, sampsPerChanToAcquire, source, activeEdge)
            %Sets the source of the Sample Clock, the rate of the Sample Clock, and the number of samples to acquire or generate.
            %
            %function cfgSampClkTiming(obj, rate, sampleMode, sampsPerChanToAcquire, source, activeEdge)
            %   rate: Sampling rate in samples per second per channel.
            %   sampleMode: One of {'DAQmx_Val_FiniteSamps','DAQmx_Val_ContSamps','DAQmx_Val_HWTimedSinglePoint'}. Specifies whether the task acquires or generates samples continuously or if it acquires or generates a finite number of samples.
            %   sampsPerChanToAcquire: (OPTIONAL) If sampleMode is DAQmx_Val_FiniteSamps, this property is mandatory, and represents the number of samples to acquire or generate for each channel in the task . If sampleMode is DAQmx_Val_ContSamps, NI-DAQmx uses this value to determine the buffer size. If empty/omitted, the DAQmx default value is used for Task's sample rate.
            %   source: (OPTIONAL) String specifying the source terminal of the Sample Clock. If empty/omitted, the internal clock is used.
            %   activeEdge: (OPTIONAL) One of {'DAQmx_Val_Rising', 'DAQmx_Val_Falling'}.  Specifies on which edge of the clock to acquire or generate samples. If empty/omitted, 'DAQmx_Val_Rising' is used.
            
            if nargin < 4 || isempty(sampsPerChanToAcquire)
                if strcmpi(sampleMode,'DAQmx_Val_FiniteSamps')
                    sampsPerChanToAcquire = 2; %This represents minimum value advisable when using FiniteSamps mode. If this isn't set, then Error -20077 can occur if writeXXX() operation precedes configuring sampQuantSampPerChan property to a non-zero value -- a bit strange, considering that it is allowed to buffer/write more data than specified to generate.
                else
                    sampsPerChanToAcquire = 0; %For input Tasks, this should force the default values to be used, given Task's sample rate and specified sampleMode.
                end
            end
            
            if nargin < 5 || isempty(source)
                source = libpointer();
            end
            if nargin < 6 || isempty(activeEdge)
                activeEdge = 'DAQmx_Val_Rising';
            end
            obj.apiCall('DAQmxCfgSampClkTiming', obj.taskID, source, rate, obj.encodePropVal(activeEdge), ...
                obj.encodePropVal(sampleMode), sampsPerChanToAcquire);
        end
        
        
        function cfgChangeDetectionTiming(obj, risingEdgeChan, fallingEdgeChan, sampleMode, sampsPerChanToAcquire)
            %Configures the task to acquire samples on the rising and/or falling edges of the lines or ports you specify.
            %
            %function cfgChangeDetectionTiming(obj, risingEdgeChan, fallingEdgeChan, sampleMode, sampsPerChanToAcquire)
            %   risingEdgeChan: The names of the digital lines or ports on which to detect rising edges.You can specify a list or range of lines and/or ports.
            %   fallingEdgeChan: The names of the digital lines or ports on which to detect falling edges.You can specify a list or range of lines and/or ports.
            %   sampleMode: One of {'DAQmx_Val_FiniteSamps','DAQmx_Val_ContSamps','DAQmx_Val_HWTimedSinglePoint'}. Specifies whether the task acquires or generates samples continuously or if it acquires or generates a finite number of samples.
            %   sampsPerChanToAcquire: (OPTIONAL) If sampleMode is DAQmx_Val_FiniteSamps, this property is mandatory, and represents the number of samples to acquire or generate for each channel in the task . If sampleMode is DAQmx_Val_ContSamps, NI-DAQmx uses this value to determine the buffer size. If empty/omitted, the DAQmx default value is used for Task's sample rate.
            
            if nargin < 4 || isempty(sampsPerChanToAcquire)
                if strcmpi(sampleMode,'DAQmx_Val_FiniteSamps')
                    sampsPerChanToAcquire = 2; %This represents minimum value advisable when using FiniteSamps mode. If this isn't set, then Error -20077 can occur if writeXXX() operation precedes configuring sampQuantSampPerChan property to a non-zero value -- a bit strange, considering that it is allowed to buffer/write more data than specified to generate.
                else
                    sampsPerChanToAcquire = 0; %For input Tasks, this should force the default values to be used, given Task's sample rate and specified sampleMode.
                end
            end
            
            obj.apiCall('DAQmxCfgChangeDetectionTiming', obj.taskID, risingEdgeChan, fallingEdgeChan, obj.encodePropVal(sampleMode), sampsPerChanToAcquire);
        end
        
        
        function cfgImplicitTiming(obj, sampleMode, sampsPerChanToAcquire)
            %Sets only the number of samples to acquire or generate without specifying timing. Typically, you should use this function when the task does not require sample timing, such as tasks that use counters for buffered frequency measurement, buffered period measurement, or pulse train generation.
            %
            %function cfgImplicitTiming(obj, sampleMode, sampsPerChanToAcquire)
            %   sampleMode: One of {'DAQmx_Val_FiniteSamps','DAQmx_Val_ContSamps','DAQmx_Val_HWTimedSinglePoint'}. Specifies whether the task acquires or generates samples continuously or if it acquires or generates a finite number of samples.
            %   sampsPerChanToAcquire: (OPTIONAL) The number of samples to acquire or generate for each channel in the task if sampleMode is DAQmx_Val_FiniteSamps. If sampleMode is DAQmx_Val_ContSamps, NI-DAQmx uses this value to determine the buffer size. If empty/omitted, the DAQmx default value is used for Task's sample rate.
            
            if nargin < 3 || isempty(sampsPerChanToAcquire)
                sampsPerChanToAcquire = 0; %This should force the default values to be used, for Task's sample rate and specified sampleMode
            end
            
            obj.apiCall('DAQmxCfgImplicitTiming', obj.taskID, obj.encodePropVal(sampleMode), sampsPerChanToAcquire);
            
        end
        
        
        %% TRIGGERING
        function cfgAnlgEdgeStartTrig(obj, triggerSource, triggerLevel, triggerSlope)
            %Configures the task to start acquiring or generating samples when an analog signal crosses the level you specify.
            %
            %function cfgAnlgEdgeStartTrig(obj, triggerSource, triggerSlope, triggerLevel)
            %   triggerSource: The name of a channel or terminal where there is an analog signal to use as the source of the trigger. For E Series devices, if you use a channel name, the channel must be the first channel in the task. The only terminal you can use for E Series devices is PFI0.
            %   triggerLevel: The threshold at which to start acquiring or generating samples. Specify this value in the units of the measurement or generation. Use triggerSlope to specify on which slope to trigger at this threshold.
            %   triggerSlope: One of {'DAQmx_Val_RisingSlope' 'DAQmx_Val_FallingSlope'}. If empty, 'DAQmx_Val_RisingSlope' is used. Specifies on which slope of the signal to start acquiring or generating samples when the signal crosses triggerLevel.
            
            
            if nargin < 4 || isempty(triggerSlope)
                triggerSlope = 'DAQmx_Val_RisingSlope';
            end
            
            obj.apiCall('DAQmxCfgAnlgEdgeStartTrig', obj.taskID, triggerSource, obj.encodePropVal(triggerSlope), triggerLevel);                            
        end
        
        function cfgDigEdgeStartTrig(obj, triggerSource, triggerEdge)
            %Configures the task to start acquiring or generating samples on a rising or falling edge of a digital signal.
            %
            %function cfgDigEdgeStartTrig(obj, triggerSource, triggerEdge)
            %   triggerSource: The name of a terminal where there is a digital signal to use as the source of the trigger.
            %   triggerEdge: (OPTIONAL) One of {'DAQmx_Val_Rising' 'DAQmx_Val_Falling'}. If empty/omitted, 'DAQmx_Val_Rising' is used. Specifies on which edge of a digital signal to start acquiring or generating samples.
            
            if nargin < 3 || isempty(triggerEdge)
                triggerEdge = 'DAQmx_Val_Rising';
            end
            
            obj.apiCall('DAQmxCfgDigEdgeStartTrig', obj.taskID, triggerSource, obj.encodePropVal(triggerEdge));
        end
        
        function disableStartTrig(obj)
            obj.apiCall('DAQmxDisableStartTrig', obj.taskID);
        end
        
        function cfgDigEdgeRefTrig(obj, triggerSource, pretriggerSamples, triggerEdge)
            %Configures the task to stop the acquisition when the device acquires all pretrigger samples, detects a rising or falling edge of a digital signal, and acquires all posttrigger samples.
            %
            %function cfgDigEdgeStartTrig(obj, triggerSource, triggerEdge)
            %   triggerSource: The name of a terminal where there is a digital signal to use as the source of the trigger.
            %   pretriggerSamples: (OPTIONAL) The minimum number of samples per channel to acquire before recognizing the Reference Trigger. The number of posttrigger samples per channel is equal to number of samples per channel in the NI-DAQmx Timing functions minus pretriggerSamples. If empty/omitted, value of 0 is used.
            %   triggerEdge: (OPTIONAL) One of {'DAQmx_Val_Rising' 'DAQmx_Val_Falling'}. If empty/omitted, 'DAQmx_Val_Rising' is used. Specifies on which edge of a digital signal to start acquiring or generating samples.
            
            if nargin < 3 || isempty(pretriggerSamples)
                pretriggerSamples = 0;
            end
            
            if nargin < 4 || isempty(triggerEdge)
                triggerEdge = 'DAQmx_Val_Rising';
            end
            
            obj.apiCall('DAQmxCfgDigEdgeRefTrig', obj.taskID, triggerSource, obj.encodePropVal(triggerEdge), pretriggerSamples);
        end
        
        
        
        
        %% READ FUNCTIONS
    
        %readXXXData() methods are generally implemented as direct MEX methods, for performance reasons
        %Some, less commonly used ones, may be implemented here in M using the DLL interface
        
        function value = readCounterDataScalar(task,timeout,suppressTimeoutError)
            %Reads a single sample from a Counter Input task.
            %function value = readCounterDataScalar(task,varargin)
            %   task: A DAQmx.Task object handle
            %   timeout: <OPTIONAL - Default=NI Default> Time, in seconds, to wait for function to complete read. Value of Inf or negative values mean to wait indefinitely. A value of 0 indicates to try once to read the requested samples. If all the requested samples are read, the function is successful. Otherwise, the function returns a timeout error and returns the samples that were actually read.
            %   suppressTimeoutError: <OPTIONAL - Default=false> If true, timeout error is suppressed and 
            %
            %   value: Counter value, returned as double.
            %
            
            if nargin < 2 || isempty(timeout)
                timeout = 10.0; %use default
            elseif isinf(timeout) || timeout < 0                
                timeout = obj.encodePropVal('DAQmx_Val_WaitInfinitely');
            end
            
            if nargin < 3 
                suppressTimeoutError = false;
            end
            
            if suppressTimeoutError
                filteredRespCodes = [-200474 -200284]; %Error -200474 ocurs if no timing configured; error -200284 if timing is configured
            else
                filteredRespCodes = [];
            end
            
            if strcmpi(get(task.channels(1),'measType'),'DAQmx_Val_CountEdges')
                value = double(task.apiCallFiltered('DAQmxReadCounterScalarU32',filteredRespCodes,task.taskID,timeout,0,libpointer()));
            else
                value = task.apiCallFiltered('DAQmxReadCounterScalarF64',filteredRespCodes,task.taskID,timeout,0,libpointer());
            end
            
            %Return empty in case where timeout error occurred
            if suppressTimeoutError && value==0
                value = [];
            end
            
        end
        
        function [outputData, sampsPerChanRead] =  readCounterData(obj,numSampsPerChan, timeout, maxOutputDataSize)
            
            %Process input arguments
            error(nargchk(1,4,nargin,'struct'));
            
            if nargin < 2 || isempty(numSampsPerChan) || isinf(numSampsPerChan) || numSampsPerChan < 0
                numSampsPerChan = -1;
            end
            
            if nargin < 3 || isempty(timeout) || isinf(timeout) || timeout < 0
                timeout = -1; 
            end            
            
            if nargin < 4 || isempty(maxOutputDataSize)
                maxOutputDataSize = 5000;
            end
            
            %VI012711: This was not a good idea -- will force 0 samples to be read, even if samples would have been read by the end of the timeout period
            %numAvailSamps = obj.get('readAvailSampPerChan');
            %numSampsPerChan = min(numSampsPerChan,numAvailSamps); 
            
            if numSampsPerChan == -1
                outputDataSize = maxOutputDataSize;
            else
                outputDataSize = numSampsPerChan;
            end
            
            if numSampsPerChan > 0
                filteredRespCodes = [-200474 -200284]; %Error -200474 ocurs if no timing configured; error -200284 if timing is configured
            else
                filteredRespCodes = [];
            end
            
            if strcmpi(get(obj.channels(1),'measType'),'DAQmx_Val_CountEdges')
                outputData = zeros(outputDataSize,1,'int32');
                [outputData, sampsPerChanRead] = double(obj.apiCallFiltered('DAQmxReadCounterU32',filteredRespCodes,obj.taskID,numSampsPerChan,timeout,outputData,outputDataSize,0,libpointer()));                
            else
                outputData = zeros(outputDataSize,1);
                [outputData, sampsPerChanRead] = obj.apiCallFiltered('DAQmxReadCounterF64',filteredRespCodes,obj.taskID,numSampsPerChan,timeout,outputData,outputDataSize,0,libpointer());                
            end            
            
            outputData(sampsPerChanRead+1:end) = [];     
        end
        
        
        %% WRITE FUNCTIONS
        
        %writeXXXData() methods are generally implemented as direct MEX methods, for performance reasons
        %Some, less commonly used ones, may be implemented here in M using the DLL interface
    
        
        function writeCounterTicksScalar(obj, highTicks, lowTicks, timeout, autoStart)
            %Writes a new pulse high tick count and low tick count to a continuous counter output task that contains a single channel.
            % function value = writeCounterTicksScalar(task, highTicks, lowTicks, timeout, autoStart)
            %   task: A DAQmx.Task object handle
            %   highTicks: The number of timebase ticks the pulse is high.
            %   lowTicks: The number of timebase ticks the pulse is low.           
            %   timeout: <OPTIONAL - Default=Inf> The amount of time, in seconds, to wait for this function to write all the samples. This function returns an error if the timeout elapses. A value of 0 indicates to try once to write the submitted samples. If this function successfully writes all submitted samples, it does not return an error. Otherwise, the function returns a timeout error and returns the number of samples actually written.
            %   autoStart: <OPTIONAL - Default=false> Specifies whether or not this function automatically starts the task if you do not start it.
 
            %Process input arguments
            error(nargchk(3,5,nargin,'struct'));
            
            if nargin < 4 || isempty(timeout) || isinf(timeout) || timeout < 0
                timeout = -1;
            end
            
            if nargin < 5 || isempty(autoStart)
                autoStart = false;
            end
            
            %Call the API
            obj.apiCall('DAQmxWriteCtrTicksScalar', obj.taskID, autoStart, timeout, highTicks, lowTicks, libpointer());
            
        end
        
        function writeCounterTimeScalar(obj, highTime, lowTime, timeout, autoStart)
            %Writes a new pulse high time and low time to a continuous counter output task that contains a single channel.
            % function writeCounterTimeScalar(obj, highTime, lowTime, timeout, autoStart)
            %   task: A DAQmx.Task object handle
            %   highTime: The number of timebase ticks the pulse is high.
            %   lowTime: The number of timebase ticks the pulse is low.
            %   timeout: <OPTIONAL - Default=Inf> The amount of time, in seconds, to wait for this function to write all the samples. This function returns an error if the timeout elapses. A value of 0 indicates to try once to write the submitted samples. If this function successfully writes all submitted samples, it does not return an error. Otherwise, the function returns a timeout error and returns the number of samples actually written.
            %   autoStart: <OPTIONAL - Default=false> Specifies whether or not this function automatically starts the task if you do not start it.
            
            
            %Process input arguments
            error(nargchk(3,5,nargin,'struct'));
            
            if nargin < 4 || isempty(timeout) || isinf(timeout) || timeout < 0
                timeout = -1;
            end
            
            if nargin < 5 || isempty(autoStart)
                autoStart = false;
            end
            
            %Call the API
            obj.apiCall('DAQmxWriteCtrTimeScalar', obj.taskID, 0, timeout, highTime, lowTime, libpointer());
                        
        end
        
        
        %% EXPORT HW SIGNALS
        function exportSignal(obj,signalID, outputTerminal)
            obj.apiCall('DAQmxExportSignal', obj.taskID, obj.encodePropVal(signalID), outputTerminal);
        end
        
        
        %% INTERNAL BUFFER CONFIGURATION
        function cfgInputBuffer(obj, numSampsPerChan)
            %Overrides the automatic output buffer allocation that NI-DAQmx performs.
            %
            %function cfgInputBuffer(obj, numSampsPerChan)
            %   numSampsPerChan: The number of samples the buffer can hold for each channel in the task. Zero indicates no buffer should be allocated. Use a buffer size of 0 to perform a hardware-timed operation without using a buffer.
            %VECTORIZED
            
            obj.cfgInputBufferEx(numSampsPerChan,false);  %Provides default DAQmx behavior of allocating an /intended/ amount of memory, deferring allocation error until Task is started (or otherwise reserved)
            
        end
        
        function sampsAllocated = cfgInputBufferVerify(obj, numSampsPerChan, reductionIncrement)
            %Overrides the automatic output buffer allocation that NI-DAQmx performs.
            %Unlike default cfgInputBuffer(), method will immediately reserve the specified memory (and will immediately produce error if unable to do so)
            %In addition, for Continuous Tasks with Sample Clock timing, if the allocation is unsuccesful, allocation of smaller amounts, in steps of 'reductionIncrement' will be tried iteratively until allocation succeeds.
            %A typical usage is where reductionIncrement = (2 * everyNSamples), which ensures that buffer size is an even multiple of everyNSamples (as required to avoid Error -200877)
            %
            %function sampsAllocated = cfgInputBufferSafe(obj, numSampsPerChan, reductionIncrement)
            %   numSampsPerChan: The number of samples the buffer can hold for each channel in the task. Zero indicates no buffer should be allocated. Use a buffer size of 0 to perform a hardware-timed operation without using a buffer.
            %   reductionIncrement: (OPTIONAL) For Continuous Tasks with Sample Clock timing, the amount by which to reduce numSampsPerChan iteratively until allocation is successful.
            %
            %   sampsAllocated: Amount of memory actually allocated
            
            
            %Parse input arguments
            if nargin < 3 || isempty(reductionIncrement)
                reductionIncrement = false;
            end
            
            %Handle cases to pass through to default behavior, with auto-reserve function enabled
            if ~reductionIncrement || ~strcmpi(obj.get('sampQuantSampMode'), 'DAQmx_Val_ContSamps') || ~strcmpi(obj.get('sampTimingType'),'DAQmx_Val_SampClk')
                sampsAllocated = numSampsPerChan;
                obj.cfgInputBufferEx(numSampsPerChan,true);
                return;
            end
            
            %Determine if there is an EveryNSamples 'floor' that cannot be crossed
            if ~isempty(obj.everyNSamples) && ~isempty(obj.everyNSamplesEventCallbacks)
                minBufSize = obj.everyNSamples;
            else
                minBufSize = 2;
            end
            
            %Attempt allocation, iteratively
            requestedNumSamps = numSampsPerChan;
            success = attemptAllocation();
            while ~success
                numSampsPerChan = numSampsPerChan - reductionIncrement;
                if numSampsPerChan >= minBufSize
                    success = attemptAllocation();
                else
                    error('DAQmx:InputBufAllocation', ['Failed to allocate memory for input buffer. Final attempt to allocate ' num2str(numSampsPerChan+reductionIncrement) ' samples was unsuccessful.']);
                end
            end
            
            %Return amount actually allocated
            sampsAllocated = numSampsPerChan;
            
            %Provide feedback
            if obj.verbose && sampsAllocated < requestedNumSamps
                disp(['Allocated input buffer of smaller size (' num2str(sampsAllocated) ' samples) than was requested (' num2str(requestedNumSamps) ' samples).']);
            end
            
            
            return;
            
            function success = attemptAllocation()
                memoryAllocationError = ['DAQmx:E' num2str(abs(obj.memoryErrorCode))];
                
                success=true;
                try
                    obj.cfgInputBufferEx(numSampsPerChan,true);
                catch ME
                    switch ME.identifier
                        case memoryAllocationError
                            success = false;
                            return;
                        otherwise
                            ME.throwAsCaller();
                    end
                end
                
            end
        end
        
        
        
        function cfgOutputBuffer(obj, numSampsPerChan)
            %Wrapper of DAQmxCfgInputBuffer, which allows the automatic output buffer allocation of DAQmx to be overridden
            %
            %function cfgOutputBuffer(obj, numSampsPerChan)
            %   numSampsPerChan: The number of samples the buffer can hold for each channel in the task. Zero indicates no buffer should be allocated. Use a buffer size of 0 to perform a hardware-timed operation without using a buffer.
            %VECTORIZED
            
            for i=1:length(obj)
                obj.apiCall('DAQmxCfgOutputBuffer', obj.taskID, numSampsPerChan);
            end
        end
        
    end
    
    %% ADVANCED FUNCTIONS
    
    %% STATIC METHODS
    methods (Static, Hidden)
        function m = getTaskMap()
            % Returns map of all tasks in current system. Key: char. Val: task objects.
            persistent taskmap;
            if isequal(taskmap,[])
                taskmap = containers.Map();
            end
            m = taskmap;
        end
        function tObjs = getAllTasks()
            map = ws.dabs.ni.daqmx.Task.getTaskMap();
            tObjs = map.values';
            tObjs = [tObjs{:}]';
        end
        function clearAllTasks()
           t = ws.dabs.ni.daqmx.Task.getAllTasks();
           delete(t);
        end
    end
    
    %% PROPERTY ACCESS METHODS
    methods (Hidden, Access=protected)
        
        function pdepPropHandleGet(obj,src,evnt)
            
            %Extend DAQmxClass pdepPropHandleGet -- apply subclass-specific apiFilteredResponseCodes
            
            %Handled errors:
            %-200478: Specified operation cannot be performed when there are no channels in the task. [Attempt to get property before channels are added]
            %-200452: Specified property is not supported by the device or is not applicable to the task. [Some properties not applicable to particular task types, e.g. for DI/DO]
            
            obj.pdepPropGroupedGet(@(propName)obj.getDAQmxProperty(propName,[-200478 -200452]),src,evnt);
        end
               
    end
    
    methods (Access=private)
        
        function val = setXXXCallbacks(obj,propName,val)
            %Shared  logic for the callback property-set methods. Coerces value to a cell array of function handles, possible empty.
            
            errMsg = ['Property ''' propName ''' must be a function handle or cell array of function handles'];
            try
                if isa(val,'function_handle')
                    val = {val};
                elseif iscell(val)
                    %Do nothing to val =
                    if ~all(cellfun(@(x)isa(x,'function_handle'),val))
                        error(errMsg);
                    end
                elseif isempty(val)
                    val = {};
                else
                    error(errMsg);
                end
            catch ME
                ME.throwAsCaller();
            end
        end
    end
    
    methods
        
        %TODO: Add set.signalEventCallbacks() and set.doneEventCallbacks(), providing error validation (i.e. ensure string, etc)
        
        function set.signalID(obj,val)
            
            if isempty(val)
                obj.registerSignalEvent(); %Unregisters Signal event, if it has been previously registered
                obj.signalID = '';
                obj.signalIDHidden = [];
            elseif ~ischar(val) || ~isvector(val) || ~ismember(val, {'DAQmx_Val_SampleClock', 'DAQmx_Val_SampleCompleteEvent', 'DAQmx_Val_ChangeDetectionEvent', 'DAQmx_Val_SampleClock', 'DAQmx_Val_CounterOutputEvent'})
                error('Unrecognized ''signalID'' name.');
            elseif ~strcmpi(val,obj.signalID)
                obj.signalID = val;
                obj.signalIDHidden = obj.encodePropVal(val);
                
                %Register automatically, if possible, every time value is updated. This forces new everyNSamples value to take.
                if ~isempty(obj.signalEventCallbacks)
                    obj.registerXXXEventPriv('signal','RegisterSignalCallback');
                end
            end
        end  
        
        
        function set.everyNSamples(obj,val)            
            
            if isempty(val)
                obj.registerEveryNSamplesEvent(); %Unregisters EveryNSamples event, if it has been previously registered
                obj.everyNSamples = [];
            elseif ~isnumeric(val) || ~isscalar(val) || round(val)~=val || val <= 0
                error('Property ''everyNSamples'' must be a positive scalar integer value');
            elseif isempty(obj.everyNSamples) || val ~= obj.everyNSamples
                obj.everyNSamples = val;
                %Register automatically, if possible, every time value is updated. This forces new everyNSamples value to take.
                if ~isempty(obj.everyNSamplesEventCallbacks)
                    obj.registerXXXEventPriv('everyNSamples','RegisterEveryNCallback');
                end
            end            
            
        end
        
        function set.everyNSamplesEventCallbacks(obj,val)
                 
            obj.everyNSamplesEventCallbacks = obj.setXXXCallbacks('everyNSamplesEventCallbacks',val);
            
            if isempty(obj.everyNSamplesEventCallbacks) %Unregister if property is set to empty
                obj.registerEveryNSamplesEvent();
                %Register automatically, if possible, every time value is updated. This forces new everyNSamplesEventCallbacks value to take.
            elseif  ~isempty(obj.everyNSamples)
                obj.registerXXXEventPriv('everyNSamples','RegisterEveryNCallback');
            end        
            
        end
        
        function set.doneEventCallbacks(obj,val)
            obj.doneEventCallbacks = obj.setXXXCallbacks('doneEventCallbacks',val);
            
            if isempty(obj.doneEventCallbacks) %Unregister if property is set to empty
                obj.registerDoneEvent();
            else %Register automatically every time value is updated. This forces new doneEventCallbacks value to take.
                obj.registerXXXEventPriv('done','RegisterDoneCallback');
            end
            
        end
        
        
        function set.signalEventCallbacks(obj,val)
            obj.signalEventCallbacks = obj.setXXXCallbacks('signalEventCallbacks',val);
            
            if isempty(obj.signalEventCallbacks) %Unregister if property is set to empty
                obj.registerSignalEvent();
            elseif ~isempty(obj.signalID) %Register automatically, if possible, every time value is updated. This forces new signalEventCallbacks value to take.
                obj.registerXXXEventPriv('signal','RegisterSignalCallback');
            end
            
        end
        
        function set.everyNSamplesReadDataEnable(obj,val)
            val = logical(val); %Force to logical type, error if not convertible
            if val
                assert(~isempty(obj.taskType),'The ''everyNSamplesReadDataEnable'' property can only be set true after one or more Channel(s) have been added to Task');
            end
            
            obj.everyNSamplesReadDataEnable = val;     
            
            %Force update of registration
            if ~isempty(obj.everyNSamplesEventCallbacks) && ~isempty(obj.everyNSamples)
                obj.registerXXXEventPriv('everyNSamples','RegisterEveryNCallback');
            end
        end
        
        function set.everyNSamplesReadTimeOut(obj,val)
            assert(isnumeric(val) && isscalar(val), 'Value of ''everyNSamplesReadTimeOut'' must be a scalar numeric');
            obj.everyNSamplesReadTimeOut = double(val);
        end
        
        function set.everyNSamplesReadDataTypeOption(obj,val)
        
            %One or more Channel(s) must be added before setting this property (to non-empty value)
            assert(isempty(val) || ~isempty(obj.taskType),'The ''everyNSamplesReadDataEnable'' property can only be set to value after one or more Channel(s) have been added to Task');
           
            obj.everyNSamplesReadDataTypeOption = '';

            if ~isempty(val)
                assert(ischar(val) && isvector(val),'The ''everyNSamplesReadDataTypeOption'' property must be a string value');
                    
                switch obj.taskType
                    case 'AnalogInput'
                        assert(ismember(lower(val),{'native' 'scaled'}),'The ''everyNSamplesReadDataTypeOption'' value must have value of ''native'' or ''scaled'' for analog input Tasks');
                        
                        obj.everyNSamplesReadDataTypeOption = lower(val);
                        
                        if strcmpi(val,'scaled')
                            obj.everyNSamplesReadDataClass = double(0); %double type
                        else
                            obj.everyNSamplesReadDataClass = obj.rawDataArrayAI; % raw data type
                        end
                        
                    case 'DigitalInput'
                        assert(ismember(lower(val),{'logical' 'double' 'uint8' 'uint16' 'uint32' }),'The ''everyNSamplesReadDataTypeOption'' value must have value of ''logical'', ''double'', ''uint8'', ''uint16'', or ''uint32'' for digital input Tasks');
                        
                        obj.everyNSamplesReadDataTypeOption = lower(val);
                    case 'CounterInput'
                        assert(ismember(lower(val),{'uint32' 'double'}),'The ''everyNSamplesReadDataTypeOption'' value must have value of ''double'' or ''uint32'' for counter input Tasks');
                        
                        measType = obj.channels(1).getQuiet('measType'); %Note -- Tasks can only contain 1 counter input channel (DAQmx restriction)
                        switch measType
                            case 'DAQmx_Val_CountEdges'
                                readDataType = 'uint32';
                            otherwise
                                readDataType = 'double';
                        end
                        
                        assert(strcmpi(readDataType,val),'The value ''%s'' cannot be used for counter input Tasks of measurement type ''%s''',lower(val),measType);
                        
                        obj.everyNSamplesReadDataTypeOption = lower(val);
                    otherwise
                        if ~isempty(val)
                            error('The ''everyNSamplesReadDataTypeOption'' property can only be set to a value for input Tasks');
                        end
                end
                            
            end
            
            %Force update of registration
            if ~isempty(obj.everyNSamplesEventCallbacks) && ~isempty(obj.everyNSamples)
                obj.registerXXXEventPriv('everyNSamples','RegisterEveryNCallback');
            end
            
        end    
        
        
        function deviceNames = get.deviceNames(obj)
            deviceNames = obj.deviceNamesHidden;
        end
        
        function devices = get.devices(obj)
            devices = obj.system.getDevicesByName(obj.deviceNames);
        end
        
        function channels = get.channels(obj)
            %TMW: This indirection is used to allow a property to be publically gettable, but only settable by 'friends' or package-mates
            channels = obj.channelsHidden; %Gets a hidden property
        end
        
        function taskType = get.taskType(obj)
            %TMW: This indirection is used to allow a property to be publically gettable, but only settable by 'friends' or package-mates
            taskType = obj.taskTypeHidden; %Gets a hidden property
        end
        
    end
    
    %% PROTECTED/PRIVATE METHODS
    methods (Access=private)
        
        function registerXXXEventPriv(obj,eventName,eventRegistrationMethod)
            
            
            flagName = [lower(eventName(1)) eventName(2:end) 'EventRegisteredFlag'];
            
            %If event has been previously registered, then un-register it before re-registering
            if obj.(flagName)
                obj.unregisterXXXEventPriv(eventName,eventRegistrationMethod); %A bit wasteful, but more elegant to call this
            end
            
            status = feval(eventRegistrationMethod,obj,true); % can throw in rare cases
            if status
                obj.(flagName) = false;
                obj.apiProcessErrorResponseCode(status); %throws an error, if found
            else
                obj.(flagName) = true;
            end
            obj.stop();
            
            ws.most.idioms.pauseTight(.01); %This seems to be necessary to gurantee that registration takes effect before subsequent start command (if it happens right away)
        end
        
        % Before unregistration, the task must be *stopped*. 
        function unregisterXXXEventPriv(obj,eventName,eventRegistrationMethod)
                        
            flagName = [eventName 'EventRegisteredFlag'];
            if obj.(flagName)                
                java.lang.Thread.sleep(10);
                  % DANGER: Potential merge bug
                  % put the thread to sleep for 10 ms.  ALT modification
                  % 2014-06-02, pause() was causing HG callbacks to run in
                  % the middle of other HG callbacks, which created
                  % problems for Wavesurfer.  Hopefully this change
                  % doesn't create a problem for ScanImage...
                % pause(.01); %This appears to help to flush any events in queue from previous registration
                
                status = feval(eventRegistrationMethod,obj,false); %Calls MEX method that actually does unregistration
                if status
                    obj.apiProcessErrorResponseCode(status); %throws an error, if found
                else
                    obj.(flagName) = false;
                end

            end
            
        end
        
        function cfgInputBufferEx(obj, numSampsPerChan, autoReserve)
            %Overrides the automatic output buffer allocation that NI-DAQmx performs.
            %
            %function cfgInputBufferEx(obj, numSampsPerChan, autoReserve)
            %   numSampsPerChan: The number of samples the buffer can hold for each channel in the task. Zero indicates no buffer should be allocated. Use a buffer size of 0 to perform a hardware-timed operation without using a buffer.
            %   autoReserve: (OPTIONAL) Logical value indicating, if true, to automatically reserve the specified number of samples. If needed, the incremental allocation strategy will be attempted to successfully allocate the specified memory.
            %
            %VECTORIZED
            
            %Parse input arguments
            if nargin < 3
                autoReserve = false;
            end
            
            try
                for i=1:length(obj)                    
                    
                    obj(i).apiCall('DAQmxCfgInputBuffer', obj(i).taskID, numSampsPerChan);
                    
                    if autoReserve
                        status = obj(i).apiCallRaw('DAQmxTaskControl',obj(i).taskID, obj(i).encodePropVal('DAQmx_Val_Task_Reserve'));
                        if status == obj(i).apiResponseCodeSuccess
                            % no-op                            
                        elseif status == -50352  %Insufficient memory..let's try to allocate iteratively.
                            status = iterativeAllocation(obj(i));
                            if status
                                obj(i).apiProcessErrorResponseCode(status,'DAQmxCfgInputBuffer'); %will throw an error, if any
                            elseif obj(i).verbose
                                disp(['Iterative strategy was required to allocate input buffer for Task ''' obj(i).taskName '''']);
                            end
                        else
                            obj(i).apiProcessErrorResponseCode(status,'DAQmxCfgInputBuffer'); %will throw an error, if any
                        end
                    end
                    
                end
                
            catch ME
                ME.throwAsCaller();
            end
            
            function status = iterativeAllocation(item)
                subBufferFractions = [.6 .7 .8 .9 1];
                
                for j = 1:length(subBufferFractions)
                    item.apiCall('DAQmxCfgInputBuffer', item.taskID, numSampsPerChan*subBufferFractions(j));
                end
                status = item.apiCallRaw('DAQmxTaskControl',item.taskID, obj.encodePropVal('DAQmx_Val_Task_Reserve'));
            end
            
        end
        
    end
    
    %% STATIC METHODS
    methods (Static)
        
        function bufSize = computeBufSizeForEveryNSamples(inputRate,bufPeriod,everyNSamples)
            %Utility to determine buffer size to use for continuous input Tasks with Every N Samples event configured
            %   inputRate: Sample rate of input Task, in Hz
            %   bufPeriod: Time, in seconds, to generally buffer data. Larger values lead to greater memory usage; less chance of data overflow.
            %   everyNSamples: Value to be subsequently configured for Task (after input buffer size is set)
            %
            %Ensures buffer size is even multiple of everyNSamples, to avoid DAQmx error -200877
            %Ensures buffer size is at least 4x the everyNSamples value (avoids some issue, not sure which)
            
            bufferFactor = ceil((inputRate * bufPeriod) / everyNSamples);
            if mod(bufferFactor,2)
                bufferFactor = bufferFactor + 1;
            end
            bufferFactor = max(bufferFactor,4); %Ensure buffer factor is at least 4
            
            bufSize = bufferFactor * everyNSamples;
        end                                                       
    end
    
end


%% HELPERS
function n = lclGetNumber()
% returns integers starting from one. every subsequent call brings the
% next bigger integer.

persistent counter;
if isempty(counter)
    counter = 0;
end

counter = counter + 1;
n = counter;

end










