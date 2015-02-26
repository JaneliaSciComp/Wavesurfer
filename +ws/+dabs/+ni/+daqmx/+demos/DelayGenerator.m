classdef DelayGenerator < handle
    %DELAYGENERATOR Object which generates a single digital output pulse with specified delay relative to each supplied input triggers
    
    properties
        deviceName=''; %DAQmx device name, as set/seen in MAX tool, e.g. 'Dev1'
        ctrID=0; %DAQmx Ctr ID on which delayed output pulse is generated. Output is routed to default output PFI terminal.
        
        restingState=0; %Resting level for digital pulse on output terminal
        pulseWidth = 10e-6;; %Time, in seconds, to dwell at non-resting state before returning to rest. If 0, shortest possible pulse duration used.
        pulseDelay = 0; %Delay, in seconds, to delay between input trigger edge and generated output pulse
        
        triggerInputTerminal=0; %PFI terminal on which input trigger is received
        triggerEdge='rising'; %One of {'rising' 'falling'}. Specifies trigger edge type.
    end
    
    properties (Hidden)
        hTask;
        timeout = 0.2;
    end   
    
    methods
        
        %% CONSTRUCTOR/DESTRUCTOR
        function obj = DelayGenerator(deviceName,ctrID,varargin)
            import ws.dabs.ni.daqmx.*
                        
            %Parse required/suggested input arguments
            obj.deviceName = deviceName;
            if nargin >=2 && ~isempty(ctrID)
                obj.ctrID = ctrID;                
            end
            
            %Handle optional arguments
            if ~isempty(varargin)
                for i=1:2:length(varargin)
                    obj.(varargin{i}) = varargin{i+1};
                end
            end
            
            %Create CO Task/Channel & initialize            
            obj.hTask = Task('Delayed Pulse Output');  
            obj.hTask.createCOPulseChanTime(obj.deviceName,obj.ctrID,'',obj.pulseWidth/10,obj.pulseWidth,0);   
            obj.triggerEdge = obj.triggerEdge;
            obj.hTask.set('startTrigRetriggerable',1)
            
        end
        
        function delete(obj)
            delete(obj.hTask);        
        end
        
    end
    
    %% PROPERTY ACCESS METHODS
    methods
        function set.restingState(obj,val)
            validateattributes(val,{'numeric'},{'scalar'});
            assert(ismember(double(val),[0 1]),'Value of restingState must be logical or 0/1 valued');
            
            obj.restingState = double(val);
            obj.zprpUpdateTimerProps('restingState');
        end
        
        function set.pulseWidth(obj,val)
            validateattributes(val,{'numeric'},{'positive' 'finite' 'scalar'});
            obj.pulseWidth = val;
            obj.zprpUpdateTimerProps('pulseWidth');            
        end
        
        function set.pulseDelay(obj,val)
            validateattributes(val,{'numeric'},{'nonnegative' 'finite' 'scalar'});
            obj.pulseDelay = val;
            obj.zprpUpdateTimerProps('pulseDelay');                        
        end
        
        function set.triggerEdge(obj,val)     
            assert(ischar(val) && isvector(val) && ismember(val,{'rising' 'falling'}),'Property ''triggerEdge'' must be one of {''rising'' ''falling''}');
            obj.triggerEdge = val;
            obj.zprpUpdateTriggerProps('triggerEdge');
        end
        
        function set.triggerInputTerminal(obj,val)
            validateattributes(val,{'numeric'},{'integer' 'nonnegative' 'finite' 'scalar'});
            obj.triggerInputTerminal = val;
            obj.zprpUpdateTriggerProps('triggerInputTerminal');
        end
        
        
    end
    
    methods (Access=protected)

        function zprpUpdateTimerProps(obj,propName)
            assert(obj.hTask.isTaskDone,'Cannot update property ''%s'' while delay generator is enabled',propName);
            
            set(obj.hTask.channels(1),'pulseTimeInitialDelay',obj.pulseDelay);
            
            switch obj.restingState
                case 0
                    lowTime = 1e-3;
                    highTime = obj.pulseWidth;
                case 1
                    lowTime = obj.pulseWidth;
                    highTime = 1e-3;
            end
                    
            set(obj.hTask.channels(1),'pulseLowTime',lowTime);
            set(obj.hTask.channels(1),'pulseHighTime',highTime);                                        
        end
        
        function zprpUpdateTriggerProps(obj,propName)
            assert(obj.hTask.isTaskDone,'Cannot update property ''%s'' while delay generator is enabled',propName);
            
            switch obj.triggerEdge
                case 'rising'
                    obj.hTask.cfgDigEdgeStartTrig(sprintf('PFI%d',obj.triggerInputTerminal),'DAQmx_Val_Rising');
                case 'falling'
                    obj.hTask.cfgDigEdgeStartTrig(sprintf('PFI%d',obj.triggerInputTerminal),'DAQmx_Val_Falling');
            end
        end               
                
    end
    
        
    
    %% PUBLIC METHODS    
    methods
        function enable(obj)
            assert(obj.hTask.isTaskDone,'Delayed pulse generator is already enabled');
            obj.hTask.start();
        end
        
        function disable(obj)
            obj.hTask.stop();
        end
        

    end
    
end

