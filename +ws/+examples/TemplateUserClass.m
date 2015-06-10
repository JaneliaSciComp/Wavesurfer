classdef TemplateUserClass < ws.UserClass

    % This is a very simple user class.  It writes to the console when
    % things like a sweep start/end happen,
    
    % Information that you want to stick around between calls to the
    % functions below, and want to be settable/gettable from the command
    % line
    properties
        Parameter1
        Parameter2
    end  % properties

    % Information that only the methods need access to.  (The underscore is
    % optional, but helps to remind you that it's protected.)
    properties (Access=protected, Transient=true)
        SomethingPrivateAndTemporary_
    end    
    
    methods
        
        function self = TemplateUserClass(wsModel)
            % creates the "user object"
            self.Parameter1 = pi ;
            self.Parameter2 = exp(1) ;            
        end
        
        function experimentWillStart(self,wsModel,eventName)
            % Called just before each set of sweeps (a.k.a. each
            % "experiment")
            fprintf('About to start an experiment.\n');
        end
        
        function sweepWillStart(self,wsModel,eventName)
            % Called just before each sweep
            fprintf('About to start a sweep.\n');
        end
        
        function sweepDidComplete(self,wsModel,eventName)
            % Called after each sweep completes
            fprintf('Finished a sweep.\n');
        end
        
        function sweepDidAbort(self,wsModel,eventName)
            % Called if a sweep goes wrong
            fprintf('Oh noes!  A sweep aborted.\n');
        end        
        
        function experimentDidComplete(self,wsModel,eventName)
            % Called just after each set of sweeps (a.k.a. each
            % "experiment")
            fprintf('Finished an experiment.\n');
        end
        
        function experimentDidAbort(self,wsModel,eventName)
            % Called if an experiment goes wrong, after the call to
            % sweepDidAbort()
            fprintf('Oh noes!  A experiment aborted.\n');
        end
        
        function dataIsAvailable(self,wsModel,eventName)
            % Called each time a "chunk" of data (typically 100 ms worth) 
            % is read from the DAQ board.
            analogData = wsModel.Acquisition.getLatestAnalogData();
            digitalData = wsModel.Acquisition.getLatestRawDigitalData(); 
            nScans = size(analogData,1);
            fprintf('Just read %d scans of data.\n',nScans);                                    
        end
        
    end  % methods
    
end  % classdef

