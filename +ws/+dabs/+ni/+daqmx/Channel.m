classdef Channel < ws.dabs.ni.daqmx.private.DAQmxClass
    %CHANNEL An Abstract object type encapsulating an NI DAQmx 'virtual channel'
    %A 'virtual channel' represents a single physical channel (Analog I/O and Counter I/O) or one or more physical lines (Digital I/O)
    %Concrete Channel objects will be of one of the valid channel types: Analog I/O, Counter I/O, or Digital I/O
    
    %% ABSTRACT PROPERTY REALIZATION (ws.dabs.ni.daqmx.private.DAQmxClass)
    properties (SetAccess=private, Hidden)
        gsPropRegExp; %Obtained via property access method
        gsPropPrefix; %Obtained via property access method
        gsPropIDArgNames = {'task.taskID' 'chanName'};
        gsPropNumStringIDArgs=1;
    end
    
    properties (SetAccess=protected)
        task; %Handle of Task with which this Channel is associated
        chanName; %Mnemonic name of channel (or default name,e.g. 'ai0' or 'port0/line0:7')
        chanNamePhysical; %Physical name of channel (the default name given by DAQmx driver)
        deviceName=''; %Name of DAQmx device on which the physical channel or line(s), e.g. 'Dev1'
    end
    
    properties (Abstract,Constant) %TMW: It complains about being Abstract & Constant,  but shouldn't!
        type; %One of: 'AnalogInput', 'AnalogOutput', 'DigitalInput', 'DigitalOutput', 'CounterInput', 'CounterOutput'
    end
    
    properties (Abstract,Hidden,Constant) %TMW: It complains about being Abstract & Constant,  but shouldn't!
        typeCode; %E.g. 'AI', for AnalogInput
        physChanIDsArgValidator; %Function handle to function imposing subclass-specific validation on physChanIDsArg (this is applied to each element of cell array, in multi-device case)
    end
    
    properties (Hidden)
        device; %Device objects for device (e.g. 'Dev1') associated with this Channel object
    end
   
    %% CONSTRUCTOR/DESTRUCTOR
    
    % Channel deletion/cleanup strategy.
    %
    % Requirements:
    % * Users cannot explicitly delete Channel-derived objects.
    % * Tasks can delete their owned Channel-derived objects (eg when a
    % Task is deleted).
    %
    % Solution:
    % * Include protected delete method in Channel. This will restrict
    % explicit deletion of Channel-derived objects.
    % * Include Hidden 'deleteHidden' method in Channel, to be called by Task.
    %
    % Important note: Channel-derived classes should NOT define their own
    % delete methods. This will most probably break the scheme.
    methods
        function obj = Channel(createFunc, task, deviceNames, physChanIDs, chanNames, varargin)
            % Channel()
            % Channel(createFunc, task, deviceNames, physChanIDs, chanNames, varargin)

            %   createFunc: DAQmx function name to use to create the channels
            %   task: Task object
            %   deviceNames: String or string cell array specifying names of device on which channel(s) should be added, e.g. 'Dev1'. If a cell array, length must match that of physChanIDs
            %   physChanIDs: Numeric or character array identifying physical channels to create, e.g. 0:2 or 'port0/line0:7'. If deviceNames is a cell array, then physChanIDs should be an equally-sized cell array of such numeric or character arrays.
            %   chanNames: (OPTIONAL) String or string cell array specifying user-defined name(s) of channels (mnemonics). If empty, the physical channel names are used. If deviceNames is a cell array, then chanNames can be either a string or must be an equally-sized cell array consisting of strings or string cell arrays.
            %   varargin (createFuncArgs): Additional function arguments, not determined/determinable from arguments 1-4, to supply to DAQmx channel creation function
            
            %Handle case where superclass construction was aborted
            if obj.cancelConstruct
                delete(obj);
                return;
            end            
           
            %Handle case of empty 
            if nargin==0
                return;
            end

            error(nargchk(5,inf,nargin,'struct'));                    
            
            %Validate that task can accept channels of desired type
            if isempty(task.taskType)
                task.taskTypeHidden = obj.type; %TMW: Have to set the 'indirect' property taskTypeHidden, since we want the taskType property to be non-user-settable
            elseif ~strcmpi(obj.type,task.taskType)
                error('Cannot add channels of differing types to Task.');
            end
            
            %Convert the deviceNames and physChanIDs arguments into cell arrays of equal length, to ease subsequent operations
            msgID = 'DAQmx:ChannelSpecificationError';
            msg = 'Arguments used to specify device and physical channel IDs are not valid';
            
            if ischar(deviceNames) && ~iscell(physChanIDs) %A single-device task
                numDevices = 1;
                %Determine if a valid single-device task
                if isValidPhysChanIDsArg(physChanIDs) && isValidChanNamesArg(chanNames)
                    %If valid single-device task, enclose into scalar cell arrays
                    deviceNames = {deviceNames};
                    physChanIDs = {physChanIDs};
                    chanNames = {chanNames};
                else
                    throw(MException(msgID,msg));
                end
            elseif iscell(deviceNames) && iscell(physChanIDs) && length(deviceNames) == length(physChanIDs) %A valid multi-device task
                numDevices = length(deviceNames);
                if isempty(chanNames)
                    chanNames = cell(1,numDevices);
                elseif ischar(chanNames)  %Shared channel name to be given to each channel (with additional distingushing info appended)
                    chanNames = repmat({chanNames},1,numDevices); %Repeat same value for each of the devices
                elseif iscell(chanNames) && ~iscellstr(chanNames) && isvector(chanNames) && length(chanNames) == numDevices
                    for i=1:length(chanNames)
                        if ~isValidChanNamesArg(chanNames{i})
                            MException(msgID,msg)
                        end
                    end
                else
                    throw(MException(msgID, msg));
                end
            else
                throw(MException(msgID, msg));
            end
            
            %Determine physical and (mnemonic) channel names given inputs for each device, using subclass implementation
            [physChanNameArray, chanNameArray] = deal(cell(1,numDevices));
            numChans = 0;
            for i=1:numDevices
                if ~isValidPhysChanIDsArg(physChanIDs{i})
                    throw(MException(msgID, msg));
                else
                    if ischar(physChanIDs{i})
                        deviceNumChans = 1; %Only allow one channel to be specified per channel creation event when using a string argument
                    elseif isnumeric(physChanIDs{i}) && isvector(physChanIDs{i})
                        deviceNumChans = length(physChanIDs{i});
                    else
                        throw(MException(msgID,[msg '\t NOTE: This should have been previously caught. This error implies a programming logic mistake']));
                    end
                    [physChanNameArray{i},chanNameArray{i}] = obj.createChanIDArrays(deviceNumChans,deviceNames{i},physChanIDs{i},chanNames{i});
                    numChans = numChans + deviceNumChans;
                end
            end
            
            %Create empty array of objects
            obj(1,numChans) = feval(class(obj));  %TMW: The feval(class()) approach allows avoiding explicitly naming this class
            
            %Create the channels
            %totalCount = get(task,'taskNumChans');
            count = 1;
            for i = 1:length(deviceNames)
                for j = 1:length(chanNameArray{i})
                    %Initialize properties
                    obj(count).task = task;
                    obj(count).deviceName = deviceNames{i};
                    obj(count).chanNamePhysical = physChanNameArray{i}{j};
                    
                    %Create the channel!
                    try
                        obj(count).apiCall(createFunc,task.taskID,physChanNameArray{i}{j},chanNameArray{i}{j},varargin{:});
                    catch ME
                        delete(obj); %Delete all the objects to be returned
                        rethrow(ME);
                    end
                    
                    %Determine actual name of added channel
                    actChanNames = getQuiet(obj(count).task,'taskChannels');
                    actChanNames = textscan(actChanNames,'%s','Delimiter',',');
                    actChanNames = actChanNames{1};
                    
                    %Store the chanName now
                    obj(count).chanName = actChanNames{end};
                    if ~isempty(chanNameArray{i}{j}) && ~strcmpi(obj(count).chanName,chanNameArray{i}{j})
                        fprintf(2,['WARNING: Specified channel name ''' chanNameArray{i}{j} ''' was not honored. ''' obj(count).chanName ''' was used instead.']);
                    end
                    
                    %Create Device object to go with channel, and bind it to Task
                    obj(count).device = ws.dabs.ni.daqmx.Device(deviceNames{i});
                    if ~ismember(deviceNames{i},task.deviceNames)
                        task.deviceNamesHidden{end+1} = deviceNames{i};
                    end
                    
                    %Bind this Channel object(s) to Task
                    task.channelsHidden = [task.channelsHidden obj(count)]; %%TMW: Have to set the 'indirect' property channelsHidden, since we want the channels property to be non-user-settable
                    
                    %Increment counts
                    count = count + 1;
                    %totalCount = totalCount + 1;
                end
            end
            
            %Handle post-creation tasks, if any
            obj.postCreationListener();
            
            return;
            
            
            %Helper functions to determine if the per-device chanName and physChanID arguments are valid
            function tf = isValidChanNamesArg(chanNameArg)
                tf = (isempty(chanNameArg) || (isvector(chanNameArg) && (ischar(chanNameArg) || iscellstr(chanNameArg))));
            end
            
            function tf = isValidPhysChanIDsArg(physChanIDArg)
                tf = isvector(physChanIDArg) && (isnumeric(physChanIDArg) || ischar(physChanIDArg)) && feval(obj.physChanIDsArgValidator,physChanIDArg);
            end
            
        end
    end
    
    methods (Access = protected)        
        function delete(obj) %#ok
        end
    end
    methods (Hidden)
        function deleteHidden(obj)
            delete(obj);
        end
    end
            
    %% PROP ACCESS METHODS
    methods
        function regExp = get.gsPropRegExp(obj)
            regExp = ['.*DAQmxGet' obj.typeCode '(?<varName>.*)\((ulong|uint64),\s*cstring,\s*(?<varType>\S*)[\),].*'];
        end
        
        function prefix = get.gsPropPrefix(obj)
            prefix = obj.typeCode;
        end
    end
    
    %% METHODS
    
    %% ABSTRACT METHODS
    methods (Abstract,Static,Hidden)
        [physChanNameArray,chanNameArray] = createChanIDArrays(deviceName,physChanIDs,chanNames);
        %Method for converting the physChanIDs and chanNames specified (for a single device, given by deviceName) to physical and mnemonic channel names, in a subclass-specific way.
        %NOTE: Validation of physChanIDs and chanNames arguments (including subclass-specific info) has already occurred.                             
    end
    
    methods (Abstract, Hidden)
       postCreationListener(obj); %Method handling tasks to handle following array construction with createChannels() method
    end
    
    
end

