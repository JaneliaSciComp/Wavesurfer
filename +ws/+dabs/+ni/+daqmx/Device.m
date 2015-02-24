classdef Device < ws.dabs.ni.daqmx.private.DAQmxClass
    %DEVICE Class encapsulating a DAQmx device
    %
    
    %NOTES
    %   At moment, it is not possible to delete Device objects.
    %   This is because of the peristent memory store containing the DeviceMap. 
    %   Without some reference counting scheme, there is no way to clear the handles stored by that Map anyway.
    
    

    %% ABSTRACT PROPERTY REALIZATION (ws.dabs.ni.daqmx.private.DAQmxClass)
    properties (SetAccess=private, Hidden)
        gsPropRegExp = '.*DAQmxGetDev(?<varName>.*)\(\s*cstring,\s*(?<varType>\S*)[\),].*'; 
        gsPropPrefix = 'Dev'; 
        gsPropIDArgNames = {'deviceName'};
        gsPropNumStringIDArgs=1;
    end

    %% PDEP PROPERTIES
    %DAQmx-defined properties explicitly added to Device, because they are commonly used. Remaining properties are added dynamically, based on demand.
    
    properties (GetObservable, SetObservable)
       productCategory; 
       productType;
       serialNum;                     
    end
    
    %% PUBLIC PROPERTIES
    properties
        deviceName='';
    end
   
    %% CONSTRUCTOR/DESTRUCTOR
    
    methods
        function obj = Device(devname,varargin)
            % obj = Device(devname,varargin)
            % Get a Device handle
            %
            % This "constructor" method typically will not create a new
            % Device object. Instead, it will return a handle to the
            % existing Device object with name devname.
            
            
            %Handle case where superclass construction was aborted
            if obj.cancelConstruct
                delete(obj);
                return;
            end
            
            error(nargchk(1,inf,nargin,'struct'));            
            
            if ~ischar(devname) || isempty(strtrim(devname))
                error('Invalid devname specified.');
            end
                        
            devmap = ws.dabs.ni.daqmx.Device.getDeviceMap();
            
            if devmap.isKey(devname)
                % vj trick: delete half-constructed obj, return existing
                obj.delete;
                obj = devmap(devname);
            elseif ws.dabs.ni.daqmx.Device.isValidDeviceName(devname)
                obj.deviceName = devname;
                devmap(devname) = obj; %#ok<NASGU>
            else
                % DAQmx doesn't know about a device by that name
                error(['There is no device ''' devname ''' in the system.']);
            end
        end        
    end
    
    methods (Access=private)
        function delete(obj) %#ok             
        end
    end        
    
    %% USER METHODS
    methods
        function reset(obj)
            %Immediately aborts all tasks associated with a device and returns the device to an initialized state. Aborting a task stops and releases any resources the task reserved.
            obj.apiCall('DAQmxResetDevice',obj.deviceName);                        
        end
        
        function selfTest(obj)
            %Causes a device to self-test.
            obj.apiCall('DAQmxSelfTestDevice',obj.deviceName);
        end        
    end
    
    %% DEVELOPER METHODS
    methods (Hidden, Static)
        function m = getDeviceMap()
            persistent map;
            if isequal(map,[])
                map = containers.Map();
            end
            m = map;            
        end
        function tf = isValidDeviceName(name)
            sys = ws.dabs.ni.daqmx.System.getHandle();
            devnames = get(sys,'devNames'); % devnames are comma-delimited
            devnames = regexp(devnames,', ','split'); % devnames is now a cellstr
            tf = ismember(lower(name),lower(devnames));
        end        
    end
    
end


