classdef System < ws.dabs.ni.daqmx.private.DAQmxClass
    %System A singleton class encapsulating the DAQmx 'System' -- i.e.
    %global DAQmx properties/methods
            
    %% ABSTRACT PROPERTY REALIZATION (ws.dabs.ni.daqmx.private.DAQmxClass) 
    properties (SetAccess=private, Hidden)
        gsPropRegExp = '.*DAQmxGetSys(?<varName>.*)\(\s*(?<varType>\S*)[\),].*';
        gsPropPrefix = 'Sys';
        gsPropIDArgNames = {};
        gsPropNumStringIDArgs = 0;
    end

    %% PDEP PROPERTIES
    %DAQmx-defined properties explicitly added to task, because they are commonly used. Remaining properties are added dynamically, based on demand.
    properties (GetObservable, SetObservable)
        devNames;
    end
    
    %% PUBLIC PROPERTIES
    
    properties (Dependent)
       tasks; %Array of all Task handles
       taskMap; %Map of taskNames to Task handles
    end
    
    %% CONSTRUCTOR/DESTRUCTOR      
    methods 
        function obj = System(varargin)
            %Returns handle to the System object, encapsulating DAQmx System properties/methods
            % function obj = System()
            %  
            
            % NOTES
            % System('singleton') can be used (internally) to generate singleton
            % Allen wanted to make the constructor private, likely thinking that getHandle() would be means of getting System object handle..but it's preferable to use constructor semantics
            
            %Handle case where superclass construction was aborted
            if obj.cancelConstruct
                delete(obj);
                return;
            end
            
            if nargin>0 && strcmp(varargin{1},'singleton')
                return;
            end
            
            % return the singleton System
            obj.delete; %TMW: Deleting existing handle allows one to use factory method from constructor(!)
            obj = ws.dabs.ni.daqmx.System.getHandle();            
        end
    end
    methods (Access=private)
        function delete(obj) %#ok<MANU>            
        end
    end
    
    %% PROPERTY ACCESS METHODS
    
    methods
        
        function val = get.tasks(obj)
            val = ws.dabs.ni.daqmx.Task.getAllTasks();            
        end
        
        function val = get.taskMap(obj)
            val = ws.dabs.ni.daqmx.Task.getTaskMap();
        end
        
    end
    
    
    %% PUBLIC METHODS    
    methods                  
        %% ADVANCED FUNCTIONS
        function connectTerms(obj, sourceTerminal, destinationTerminal, signalModifiers) 
            %Creates a route between a source and destination terminal. The route can carry a variety of digital signals, such as triggers, clocks, and hardware events.
            %These source and destination terminals can be on different devices as long as a connecting public bus, such as RTSI or the PXI backplane, is available. DAQmxConnectTerms does not modify a task. When connectTerms() runs, the route is immediately reserved and committed to hardware. This type of routing is called immediate routing.
            %
            %function connectTerms(obj, sourceTerminal, destinationTerminal, signalModifiers)
            %   sourceTerminal: The originating terminal of the route. You can specify a terminal name.
            %   destinationTerminal: The receiving terminal of the route. You can specify a terminal name.
            %   signalModifiers: (OPTIONAL) One of {'DAQmx_Val_InvertPolarity','DAQmx_Val_DoNotInvertPolarity'}. If empty/omitted, 'DAQmx_Val_DoNotInvertPolarity' is used. Specifies whether or not to invert the signal routed from the sourceTerminal to the destinationTerminal. If the device is not capable of signal inversion or if a previous route reserved the inversion circuitry in an incompatible configuration, attempting to invert the signal causes an error.                        
            
            if nargin < 4 || isempty(signalModifiers)
                signalModifiers = 'DAQmx_Val_DoNotInvertPolarity';
            end
            
            obj.apiCall('DAQmxConnectTerms',sourceTerminal,destinationTerminal,obj.encodePropVal(signalModifiers));
        end
        
        function disconnectTerms(obj, sourceTerminal, destinationTerminal) 
            %Removes signal routes previously created using DAQmxConnectTerms. DAQmxDisconnectTerms cannot remove task-based routes, such as those created through timing and triggering configuration.
            %When this function executes, the route is unreserved immediately. For this reason, this type of routing is called immediate routing.
            %
            %function disconnectTerms(obj, sourceTerminal, destinationTerminal)
            %   sourceTerminal: The originating terminal of the route. You can specify a terminal name.
            %   destinationTerminal: The receiving terminal of the route. You can specify a terminal name.
            
            obj.apiCall('DAQmxDisconnectTerms',sourceTerminal,destinationTerminal);
        end
     
        function tristateOutputTerm(obj, outputTerminal)
            %Sets a terminal to high-impedance state. If you connect an external signal to a terminal on the I/O connector, the terminal must be in high-impedance state. Otherwise, the device could double-drive the terminal and damage the hardware. If you use this function on a terminal in an active route, the function fails and returns an error.
            %DAQmxResetDevice sets all terminals on the I/O connector to high-impedance state but aborts any running tasks associated with the device.
            %
            %function tristateOutputTerm(obj, outputTerminal)
            %   outputTerminal: The terminal on the I/O connector to set to high-impedance state. You can specify a terminal name.
            %
            
            obj.apiCall('DAQmxTristateOutputTerm', outputTerminal);            
        end
        
        %% SYSTEM CONFIGURATION
        function setAnalogPowerUpStates(obj) %#ok
            
        end
        
        function setDigitalLogicFamilyPowerUpStates(obj)%#ok
            
        end
        
        function setDigitalPowerUpStates(obj)%#ok
            
        end            
    end
     
    %% STATIC METHODS
    methods (Static,Hidden)       
        function obj = getHandle()            
            %Get a handle to the singleton System object
            persistent localObj;
            if isempty(localObj) || ~isvalid(localObj)
                localObj = ws.dabs.ni.daqmx.System('singleton');
            end
            obj = localObj;
        end        
    end    
end


    

