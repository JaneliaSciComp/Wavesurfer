classdef UserClass < handle
    % The superclass from which user classes should inherit.  Contains methods
    % that get called at various points, including during a run.
    %
    % A user class should include a zero-argument constructor.  Any initialization
    % requiring information from the WavesurferModel should be done in the wake()
    % method, which takes the root model as an argument.  By checking the class of
    % the rootModel, initialization can be customized to the process.
    %
    % Any non-transient, non-dependent properties of the user object are saved
    % to the protocol file, and are also serialized and sent to the refiller
    % and loooper at the start of each run.      

    methods (Abstract=true)
        wake(self, wsModel)
          % Called once after the user object is created, reinstantiated, or loaded from a
          % protocol file.  Note that when a protocol file is loaded, a user object
          % is first created in a temporary version of the WavesurferModel, then if
          % that succeeds, the one true WavesurferModel is made to mimic the temporary
          % one.  But wake() is only called on the user object after this.  Thus the
          % non-transient, non-dependent properties of the user object should be set
          % as in the protocol file, but the transient properties will generally not
          % be set to sensible values.  If needed, the wake() method should set
          % the transient values to preserve any user object invarients.
        willSaveToProtocolFile(self, wsModel)
        
        startingRun(self, wsModel)
        completingRun(self, wsModel)
        stoppingRun(self, wsModel)
        abortingRun(self, wsModel)
        startingSweep(self, wsModel)        
        completingSweep(self, wsModel)      
        stoppingSweep(self, wsModel)      
        abortingSweep(self, wsModel)
        dataAvailable(self, wsModel)
        
        startingEpisode(self, wsModel)        
        completingEpisode(self, wsModel)      
        stoppingEpisode(self, wsModel)      
        abortingEpisode(self, wsModel)
        
        % Allows access to private and protected variables for encoding.        
        result = getPropertyValue_(self, name)
        setPropertyValue_(self, name, newValue)
        
        mimic(self, other)
        
        % These are intended for getting/setting *public* properties.
        % I.e. they are for general use, not restricted to special cases like
        % encoding or ugly hacks.        
        result = get(self, propertyName) 
        set(self, propertyName, newValue)
    end  % public abstract methods block            
    
end  % classdef
