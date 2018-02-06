classdef UserClass < ws.Coding
    % The superclass from which user classes should inherit.  Contains methods
    % that get called at various points, including during a run.  The user
    % class gets instantiated in *each* of the three main processes of WS: the
    % frontend, the looper, and the refiller.  Some methods get called in only
    % one of the processes, and soe get called in all of the processes.  The
    % user object is serialized in the frontend and sent to each of the
    % refiller and looper at the start of each run.
    %
    % A user class should include a zero-argument constructor.  Any
    % initialization requiring information from the WavesurferModel (or the
    % Looper, or the Refiller) should be done in the wake() method, which takes
    % the root model as an argument.  By checking the class of the rootModel,
    % initialization can be customized to the process.
    %
    % Any non-transient, non-dependent properties of the user object are saved
    % to the protocol file, and are also serialized and sent to the refiller
    % and loooper at the start of each run.  
    

    methods (Abstract=true)
        % this one is called in all processes
        wake(self, rootModel)
          % Called once after the user object is created, reinstantiated, or loaded from a
          % protocol file.  Note that when a protocol file is loaded, a user object
          % is first created in a temporary version of the WavesurferModel, then if
          % that succeeds, the one true WavesurferModel is made to mimic the temporary
          % one.  But wake() is only called on the user object after this.  Thus the
          % non-transient, non-dependent properties of the user object should be set
          % as in the protocol file, but the transient properties will generally not
          % be set to sensible values.  If needed, the wake() method should set
          % the transient values to preserve any user object invarients.
          
        % these are called in the frontend process
        startingRun(self, wsModel)
        completingRun(self, wsModel)
        stoppingRun(self, wsModel)
        abortingRun(self, wsModel)
        startingSweep(self, wsModel)        
        completingSweep(self, wsModel)      
        stoppingSweep(self, wsModel)      
        abortingSweep(self, wsModel)
        dataAvailable(self, wsModel)
        
        % this one is called in the looper process
        samplesAcquired(self, looper, analogData, digitalData) 
        
        % these are are called in the refiller process
        startingEpisode(self, refiller)        
        completingEpisode(self, refiller)      
        stoppingEpisode(self, refiller)      
        abortingEpisode(self, refiller)        
    end  % methods

%     methods 
%         function other = copy(self)
%             className = class(self) ;
%             other = feval(className) ;
%             other.mimic(self) ;            
%         end  % function                
%     end
    
end  % classdef
