classdef (Abstract) Subsystem < ws.Model
    %Subsystem Default base class for Wavesurfer subsystem implementations
    %
    %   The Subsystem class defines the Wavesurfer subsystem API and defines default
    %   (no-op) implementations for each API method and property.
    
    properties (Dependent = true)
        IsEnabled
    end
    
    properties (Access = protected)
        IsEnabled_ = false
    end
    
    events 
        DidSetIsEnabled
    end
    
    methods
        function self = Subsystem(parent)
            self@ws.Model(parent) ;
        end
                
        function out = get.IsEnabled(self)
            out = self.getIsEnabledImplementation();
            % out = self.IsIsEnabled_ && self.CanEnable;
        end
        
        function set.IsEnabled(self, value)
            self.setIsEnabledImplementation_(value);            
        end
        
        function startingRun(self) %#ok<MANU>
        end
        
        function completingRun(self) %#ok<MANU>
        end
        
        function stoppingRun(self) %#ok<MANU>
        end
        
        function abortingRun(self) %#ok<MANU>
            % Called if a failure occurred during startingRun() for subsystems
            % that have already passed startingRun() to clean up, and called fater
            % abortingSweep().
            
            % This code MUST be exception free.
        end
        
        function startingSweep(~)          % self
        end
        
        function completingSweep(~)           % self
        end
        
        function stoppingSweep(~)           % self
        end
        
        function abortingSweep(~)              % self
            % Called when a sweep is interrupted, either unexpectedly because of an error,
            % or intentionally such as stopping preview mode or stopping an ephys test
            % pulse.
            
            % This code MUST be exception free.
        end
        
%         function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD>
%         end

        function mimicWavesurferModel_(self, other)
            % This is only every called when self is a subsystem of a
            % Looper or Refiller object, and other is the corresponding
            % subsystem of a WavesurferModel object.  It is used to sync
            % the satellite settings to the WavesurferModel settings.
            self.mimic(other) ;
        end

        function do(self, methodName, varargin)
            % This is intended to be the usual way of calling model
            % methods.  For instance, a call to a ws.Controller
            % controlActuated() method should generally result in a single
            % call to .do() on it's model object, and zero direct calls to
            % model methods.  This gives us a
            % good way to implement functionality that is common to all
            % model method calls, when they are called as the main "thing"
            % the user wanted to accomplish.  For instance, we start
            % warning logging near the beginning of the .do() method, and turn
            % it off near the end.  That way we don't have to do it for
            % each model method, and we only do it once per user command.            
            root = self.Parent ;
            root.startLoggingWarnings() ;
            try
                self.(methodName)(varargin{:}) ;
            catch exception
                % If there's a real exception, the warnings no longer
                % matter.  But we want to restore the model to the
                % non-logging state.
                root.stopLoggingWarnings() ;  % discard the result, which might contain warnings
                rethrow(exception) ;
            end
            warningExceptionMaybe = root.stopLoggingWarnings() ;
            if ~isempty(warningExceptionMaybe) ,
                warningException = warningExceptionMaybe{1} ;
                throw(warningException) ;
            end
        end

        function logWarning(self, identifier, message, causeOrEmpty)
            % Hand off to the WSM, since it does the warning logging
            if nargin<4 ,
                causeOrEmpty = [] ;
            end
            self.Parent.logWarning(identifier, message, causeOrEmpty) ;
        end  % method        
    end  % methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Model(self);
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%         end
        
        function out = getIsEnabledImplementation(self)
            out = self.IsEnabled_;
        end
        
        function setIsEnabledImplementation_(self, newValue)
            if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                self.IsEnabled_ = logical(newValue) ;
                didSucceed = true ;
            else
                didSucceed = false ;
            end
            self.broadcast('DidSetIsEnabled') ;
            if ~didSucceed ,
                error('ws:invalidPropertyValue', ...
                      'IsEnabled must be a scalar, and must be logical, 0, or 1') ;
            end
        end  % function
    end  % protected methods block            
    
end  % classdef
