classdef PulseGenerator
    %PULSEGENERATOR Summary of this class goes here
    
    properties
        deviceName=''; %DAQmx device name, as set/seen in MAX tool, e.g. 'Dev1'
        lineNumber=0;  %Digital Output line number on which pulses will be generated        
        portNumber=0;  %Digital Output port number on which the line to generate output pulses on resides
        restingState=0; %Logical level at which     
        pulseWidth = 0; %Time in seconds to dwell at non-resting state before returning to rest. If 0, shortest possible pulse duration used.
    end
    
    properties (Hidden)
        hTask;
        timeout = 0.2;
    end
    
    properties (Access=private,Dependent)
        outputPattern;        
    end
    
    methods
        
        %% CONSTRUCTOR/DESTRUCTOR
        function obj = PulseGenerator(deviceName,lineNumber,varargin)
            import ws.dabs.ni.daqmx.*
                        
            %Parse required/suggested input arguments
            obj.deviceName = deviceName;
            if nargin >=2 && ~isempty(lineNumber)
                obj.lineNumber = lineNumber;                
            end
            
            %Handle optional arguments
            if ~isempty(varargin)
                for i=1:2:length(varargin)
                    obj.(varargin{i}) = varargin{i+1};
                end
            end
            
            %Create DO Task/Channel & initialize            
            obj.hTask = Task();  
            obj.hTask.createDOChan(obj.deviceName,sprintf('port%d/line%d',obj.portNumber,obj.lineNumber));           
            obj.hTask.writeDigitalData(logical(obj.restingState),obj.timeout,true);            

        end
        
%         function delete(obj)
%             delete(obj.hTask);        
%         end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function outputPattern = get.outputPattern(obj)
            
            if obj.restingState
                outputPattern = logical([1;0;1]);
            else
                outputPattern = logical([0;1;0]);
            end           
        end
        
    end
    
    
    methods
        function go(obj)
            if obj.pulseWidth == 0
                obj.hTask.writeDigitalData(obj.outputPattern,obj.timeout,true);
            else
                obj.hTask.writeDigitalData(obj.outputPattern(1:2),obj.timeout,true);
                pause(obj.pulseWidth);
                obj.hTask.writeDigitalData(obj.outputPattern(3),obj.timeout,true);
            end

        end
        
    end
    
end

