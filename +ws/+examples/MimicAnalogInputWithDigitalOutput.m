classdef MimicAnalogInputWithDigitalOutput < ws.UserClass

    % This is a very simple user class.  It writes to the console when
    % things like a sweep start/end happen,
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from the command
    % line.
    properties
    end  % properties

    % Information that only the methods need access to.  (The underscore is
    % optional, but helps to remind you that it's protected.)
    properties (Access=protected, Transient=true)
    end
    
    methods        
        function self = MimicAnalogInputWithDigitalOutput()
            % creates the "user object"
            fprintf('Instantiating an instance of MimicAnalogInputWithDigitalOutput.\n');
            %self.Parameter1 = pi ;
            %self.Parameter2 = exp(1) ;            
        end
        
        function wake(self, rootModel)  %#ok<INUSD>
            fprintf('Waking an instance of MimicAnalogInputWithDigitalOutput.\n');
        end
        
        % These methods are called in the frontend process
        function startingRun(self,wsModel) %#ok<INUSD>
            % Called just before each set of sweeps (a.k.a. each
            % "run")
            fprintf('About to start a run.\n');
        end
        
        function completingRun(self,wsModel) %#ok<INUSL>
            % Called just after each set of sweeps (a.k.a. each
            % "run")
            fprintf('Completed a run.\n');
            wsModel.DOChannelStateIfUntimed(1) = false ;  % don't want this left high
        end
        
        function stoppingRun(self,wsModel) %#ok<INUSL>
            % Called if a sweep goes wrong
            fprintf('User stopped a run.\n');
            wsModel.DOChannelStateIfUntimed(1) = false ;  % don't want this left high
        end        
        
        function abortingRun(self,wsModel) %#ok<INUSL>
            % Called if a run goes wrong, after the call to
            % abortingSweep()
            fprintf('Oh noes!  A run aborted.\n');
            wsModel.DOChannelStateIfUntimed(1) = false ;  % don't want this left high
        end
        
        function startingSweep(self,wsModel) %#ok<INUSD>
            % Called just before each sweep
            fprintf('About to start a sweep.\n');
        end
        
        function completingSweep(self,wsModel) %#ok<INUSD>
            % Called after each sweep completes
            fprintf('Completed a sweep.\n');
        end
        
        function stoppingSweep(self,wsModel) %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('User stopped a sweep.\n');
        end        
        
        function abortingSweep(self,wsModel) %#ok<INUSD>
            % Called if a sweep goes wrong
            fprintf('Oh noes!  A sweep aborted.\n');
        end        
        
        function dataAvailable(self,wsModel) %#ok<INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % is read from the DAQ board.
%             analogData = wsModel.Acquisition.getLatestAnalogData();
%             digitalData = wsModel.Acquisition.getLatestRawDigitalData(); 
%             nScans = size(analogData,1);
%             fprintf('Just read %d scans of data.\n',nScans);                                    
        end
        
        % These methods are called in the looper process
        function samplesAcquired(self,looper,analogData,digitalData)  %#ok<INUSL,INUSD>
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % is read from the DAQ board.
            %analogData = wsModel.Acquisition.getLatestAnalogData();
            %digitalData = wsModel.Acquisition.getLatestRawDigitalData(); 
            %fprintf('MimicAnalogInputWithDigitalInput::samplesAcquired()\n');
            vSample = analogData(end,1);  % this method only gets called when nScans>=1
%             wsModel.DOChannelStateIfUntimed(1) = ...
%                 (vSample>2.5) ;
            newOutput = (vSample>2.5) ;
            looper.setDigitalOutputStateIfUntimedQuicklyAndDirtily(newOutput) ;
            %fprintf('Just read %d scans of data.\n',nScans);                                    
        end
        
        % These methods are called in the refiller process
        function startingEpisode(self,refiller) %#ok<INUSD>
            % Called just before each episode
            %fprintf('About to start an episode.\n');
        end
        
        function completingEpisode(self,refiller) %#ok<INUSD>
            % Called after each episode completes
            %fprintf('Completed an episode.\n');
        end
        
        function stoppingEpisode(self,refiller) %#ok<INUSD>
            % Called if a episode goes wrong
            %fprintf('User stopped an episode.\n');
        end        
        
        function abortingEpisode(self,refiller) %#ok<INUSD>
            % Called if a episode goes wrong
            %fprintf('Oh noes!  An episode aborted.\n');
        end
    end  % methods
    
end  % classdef

