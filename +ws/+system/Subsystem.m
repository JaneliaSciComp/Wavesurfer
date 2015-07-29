classdef Subsystem < ws.Model %& ws.EventBroadcaster
    %Subsystem Default base class for Wavesurfer subsystem implementations
    %
    %   The Subsystem class defines the Wavesurfer subsystem API and defines default
    %   (no-op) implementations for each API method and property.
    
    properties (Dependent = true)
        Parent  
        Enabled
    end
    
    properties (SetAccess = protected, Dependent = true)
        CanEnable  
            % boolean scalar, true iff the subsystem can be enabled.
            % Typically, subsystems set this to false in the constructor,
            % and only set it to true once they have been initialized
            % (often using information in the MDF file).
    end

    properties (Access = protected, Transient=true)
        Parent_  % must be set in subclass constructor
        CanEnable_ = false
    end

    properties (Access = protected)
        Enabled_ = false
    end
    
    events 
        DidSetEnabled
    end
    
    methods
        function delete(self)
            self.Parent_ = [] ;
        end
        
        function out = get.Parent(self)
            out = self.Parent_ ;
        end
        
        function out = get.Enabled(self)
            out = self.getEnabledImplementation();
            % out = self.Enabled_ && self.CanEnable;
        end
        
        function set.Enabled(self, value)
            self.setEnabledImplementation_(value);            
        end
        
        function out = get.CanEnable(self)
            out = self.getCanEnableImplementation();
        end
        
        function set.CanEnable(self, value)
            self.setCanEnableImplementation(value);
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
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.most.app.Model(self);
%             self.setPropertyAttributeFeatures('Enabled', 'Classes', 'binarylogical');
%             self.setPropertyAttributeFeatures('CanEnable', 'Classes', 'binarylogical');
%         end

        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.Model(self);
            self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'header'});
%             self.setPropertyTags('CanEnable', 'ExcludeFromFileTypes', {'*'});
%             self.setPropertyTags('Enabled', 'IncludeInFileTypes', {'cfg'}, 'ExcludeFromFileTypes', {'usr'});            
%             self.setPropertyTags('Parent', 'ExcludeFromFileTypes', {'*'});            
        end
        
        function out = getEnabledImplementation(self)
            out = self.Enabled_;
        end
        
        function setEnabledImplementation_(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    % do nothing
                else
                    error('most:Model:invalidPropVal', ...
                          'Enabled must be a scalar, and must be logical, 0, or 1');
                end
                if self.CanEnable_ ,                
                    self.Enabled_ = logical(newValue);
                end
            end
            self.broadcast('DidSetEnabled');
        end
        
        function out = getCanEnableImplementation(self)
            out = self.CanEnable_;            
        end
        
        function setCanEnableImplementation(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                    self.CanEnable_ = logical(newValue);
                else
                    error('most:Model:invalidPropVal', ...
                          'CanEnable must be a scalar, and must be logical, 0, or 1');
                end
            end
            % no broadcast needed in this case
        end
    end  % protected methods block
    
%     methods (Hidden)
%         function debug_description(~)
%         end
%     end
    
    properties (Hidden, SetAccess=protected)
        %mdlPropAttributes = ws.system.Subsystem.propertyAttributes();        
        %mdlHeaderExcludeProps = {};
    end
    
%     methods (Static)
%         function s = propertyAttributes()
%             s = struct();
% 
%             s.Enabled = struct('Classes','binarylogical');
%             s.CanEnable = struct('Classes','binarylogical');            
%         end  % function
%     end  % class methods block
    
    
end
