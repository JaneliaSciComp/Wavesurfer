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
        
        function willPerformRun(self) %#ok<MANU>
        end
        
        function didCompleteRun(self) %#ok<MANU>
        end
        
        function didAbortRun(self) %#ok<MANU>
            % Called if a failure occurred during willPerformRun() for subsystems
            % that have already passed willPerformRun() to clean up, and called fater
            % didAbortSweep().
            
            % This code MUST be exception free.
        end
        
        function willPerformSweep(~)          % self
        end
        
        function didCompleteSweep(~)           % self
        end
        
        function didAbortSweep(~)              % self
            % Called when a sweep is interrupted, either unexpectedly because of an error,
            % or intentionally such as stopping preview mode or stopping an ephys test
            % pulse.
            
            % This code MUST be exception free.
        end
        
        function dataIsAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD>
        end
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
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.IsEnabled_ = logical(newValue);
                else
                    self.broadcast('DidSetIsEnabled');
                    error('most:Model:invalidPropVal', ...
                          'IsEnabled must be a scalar, and must be logical, 0, or 1');
                end
            end
            self.broadcast('DidSetIsEnabled');
        end
    end            
    
end
