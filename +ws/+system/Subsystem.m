classdef Subsystem < ws.Model %& ws.EventBroadcaster
    %Subsystem Default base class for Wavesurfer subsystem implementations
    %
    %   The Subsystem class defines the Wavesurfer subsystem API and defines default
    %   (no-op) implementations for each API method and property.
    
    properties (SetAccess = protected, Transient=true)
        Parent  % must be set in subclass constructor
    end
    
    properties (Dependent = true)
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
        CanEnable_ = false
    end

    properties (Access = protected)
        Enabled_ = false
    end
    
    events 
        DidSetEnabled
    end
    
    methods
%         function unstring(self)
%             % Called to eliminate all the child-to-parent references, so
%             % that all the descendents will be properly deleted once the
%             % last reference to the WavesurferModel goes away.
%             self.Parent=[];
%         end
        
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
        
        % Passes the appState that the system will be going into (e.g., run, preview,
        % ...) in case that matters to the subsystem, since the wavesurferObj State property
        % is still Idle at this moment.
        function willPerformExperiment(self, wavesurferModel, desiredApplicationState) %#ok<INUSD>
        end
        
        function didPerformExperiment(self, wavesurferModel) %#ok<INUSD>
        end
        
        function didAbortExperiment(self, wavesurferModel) %#ok<INUSD>
            % Called if a failure occurred during willPerformExperiment() for subsystems
            % that have already passed willPerformExperiment() to clean up, and called fater
            % didAbortTrial().
            
            % This code MUST be exception free.
        end
        
        function willPerformTrial(~, ~)          % self, wavesurferObj
        end
        
        function didPerformTrial(~, ~)           % self, wavesurferObj
        end
        
        function didAbortTrial(~, ~)              % self, wavesurferObj
            % Called when a trial is interrupted, either unexpectedly because of an error,
            % or intentionally such as stopping preview mode or stopping an ephys test
            % pulse.
            
            % This code MUST be exception free.
        end
        
        function dataIsAvailable(self, state, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData) %#ok<INUSD>
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
        
        function setEnabledImplementation_(self, value)
            %self.validatePropArg('Enabled', value);
            if isfloat(value) && isscalar(value) && isnan(value) ,
                % do nothing
            else
                value = self.validatePropArg('Enabled',value);
                % Shouldn't we check to make sure CanEnable is true before
                % setting this to true?
                if self.CanEnable_ ,                
                    self.Enabled_ = value;
                end
            end
            self.broadcast('DidSetEnabled');
        end
        
        function out = getCanEnableImplementation(self)
            out = self.CanEnable_;
        end
        
        function setCanEnableImplementation(self, value)
            %self.validatePropArg('CanEnable', value);
            if isa(value,'ws.most.util.Nonvalue'), return, end            
            value = self.validatePropArg('CanEnable',value);
            self.CanEnable_ = value;
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
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();

            s.Enabled = struct('Classes','binarylogical');
            s.CanEnable = struct('Classes','binarylogical');            
        end  % function
    end  % class methods block
    
    
end
