classdef Ephys < ws.system.Subsystem
    %Ephys  Wavesurfer subsystem responsible for most Ephys-related behaviors.
    %
    %    The Ephys subsystem manages electrode configuration and settings
    %    communication for Wavesurfer electrophysiology experiments.
    
    %%
    properties (Access = protected)
        ElectrodeManager_
        TestPulser_
    end
    
    %%
    properties (Dependent=true, SetAccess=immutable)
        ElectrodeManager  % provides public access to ElectrodeManager_
        TestPulser  % provides public access to TestPulser_
    end    
      
    %%
%     events
%         MayHaveChanged
%     end

    %%
    methods
        %%
        function self = Ephys(parent)
            self.CanEnable=true;
            self.Enabled=true;            
            self.Parent=parent;
            self.ElectrodeManager_=ws.ElectrodeManager('Parent',self);
            self.TestPulser_=ws.TestPulser('Parent',self);
        end
        
        %%
        function delete(self)
            self.Parent=[];  % eliminate reference to host WavesurferModel object
            delete(self.TestPulser_);  % do i need this?
            delete(self.ElectrodeManager_);  % do i need this?
        end
        
        %%
        function out = get.TestPulser(self)
            out=self.TestPulser_;
        end
        
        %%
        function out = get.ElectrodeManager(self)
            out=self.ElectrodeManager_;
        end
        
        %%
%         function initializeUsingMDF(self, mdfData)
%             % This method is the public interface to establishing hardware other
%             % configuration information defined in the machine data file.  It is called from
%             % WavesurferModel.initializeFromMDF() when it is first loaded with a machine data file.
%             
%             self.ElectrodeManager_=ws.ElectrodeManager('Parent',self);            
%             for idx = 1:1000 ,
%                 electrodeId = sprintf('electrode%d', idx);
%                 
%                 if ~isfield(mdfData, [electrodeId 'Type'])
%                     break;
%                 end
%                 
%                 if isempty(mdfData.([electrodeId 'Type']))
%                     continue;
%                 end
%                 
%                 % If you have p-v pairs defined in mdf entries such as 'electrode1Properties',
%                 % they get applied here in the constructor for the device-specific
%                 % electrode class.
%                 electrodeType=mdfData.([electrodeId 'Type']);
%                 electrodeClassName=[electrodeType 'Electrode'];
%                 electrodeFullClassName=['ws.ephys.vendor.' electrodeClassName];
%                 electrode = feval(electrodeFullClassName, self, mdfData.([electrodeId 'Properties']){:});
%                 
%                 % Sort out the output and input channel names.
%                 electrode.VoltageCommandChannelName = mdfData.([electrodeId 'VoltageCommandChannelName']);
%                 electrode.CurrentCommandChannelName = mdfData.([electrodeId 'CurrentCommandChannelName']);
%                 electrode.VoltageMonitorChannelName = mdfData.([electrodeId 'VoltageMonitorChannelName']);
%                 electrode.CurrentMonitorChannelName = mdfData.([electrodeId 'CurrentMonitorChannelName']);
%                 
%                 % DAQ channels related to configuration reading/writing, where applicable.
%                 electrode.setConfigurationChannels(mdfData.([electrodeId 'ConfigChannelNames']));
%                 
%                 % If the electrode name was not set from a PV pair in the mdf give it a
%                 % reasonable default.
%                 if isempty(electrode.Name)
%                     electrode.Name = sprintf('Electrode %d', numel(self.Electrodes_) + 1);
%                 end
%                 
%                 self.ElectrodeManager_.addElectrode(electrode)
%                 %self.Electrodes{end + 1} = electrode;
%             end
%             
%             self.TestPulser_=ws.TestPulser('Parent',self);
%         end
        
%         function acquireHardwareResources(self) %#ok<MANU>
%             % Nothing to do here, maybe
%         end  % function
% 
        function releaseHardwareResources(self) %#ok<MANU>
            % Nothing to do here, maybe
        end

        %%
        function electrodeMayHaveChanged(self,electrode,propertyName)
            % Called by the ElectrodeManager to notify that the electrode
            % may have changed.
            % Currently, tells TestPulser about the change, and the parent
            % WavesurferModel.
            if ~isempty(self.TestPulser_)
                self.TestPulser_.electrodeMayHaveChanged(electrode,propertyName);
            end
            if ~isempty(self.Parent)
                self.Parent.electrodeMayHaveChanged(electrode,propertyName);
            end
        end

        %%
        function electrodeWasAdded(self,electrode)
            % Called by the ElectrodeManager when an electrode is added.
            % Currently, informs the TestPulser of the change.
            if ~isempty(self.TestPulser_)
                self.TestPulser_.electrodeWasAdded(electrode);
            end
        end

        %%
        function electrodesRemoved(self)
            % Called by the ElectrodeManager when one or more electrodes
            % are removed.
            % Currently, informs the TestPulser of the change.
            if ~isempty(self.TestPulser_)
                self.TestPulser_.electrodesRemoved();
            end
            if ~isempty(self.Parent)
                self.Parent.electrodesRemoved();
            end
        end

        %% 
        function self=didSetAnalogChannelUnitsOrScales(self)
            testPulser=self.TestPulser;
            if ~isempty(testPulser) ,
                testPulser.didSetAnalogChannelUnitsOrScales();
            end            
        end       
        
        %%
        function isElectrodeMarkedForTestPulseMayHaveChanged(self)
            if ~isempty(self.TestPulser_)
                self.TestPulser_.isElectrodeMarkedForTestPulseMayHaveChanged();
            end
        end
                
        %%
        function willPerformExperiment(self, wavesurferObj, experimentMode) %#ok<INUSD>
            % Update all the gains and modes that are associated with smart
            % electrodes
            self.ElectrodeManager_.updateSmartElectrodeGainsAndModes();
        end
        
        %%
        function didPerformExperiment(self, wavesurferModel) %#ok<INUSD>
        end
        
        %%
        function didAbortExperiment(self, wavesurferModel) %#ok<INUSD>
        end
        
        function didSetAcquisitionSampleRate(self,newValue)
            testPulser = self.TestPulser ;
            if ~isempty(testPulser) ,
                testPulser.didSetAcquisitionSampleRate(newValue) ;
            end
        end        
    end  % methods block
    
    
    %%
    methods (Access = protected)
%         %%
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.system.Subsystem(self);
%         end
        
        %%
        function defineDefaultPropertyTags(self)
            defineDefaultPropertyTags@ws.system.Subsystem(self);            
            
            self.setPropertyTags('TestPulser', 'ExcludeFromFileTypes', {'header'});
        end
        
        %% Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end
        
        %% Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            if nargin < 3
                value = [];
            end
            self.(name) = value;
        end
    end  % protected methods block
    
    %%
    methods (Access=public)
%         %%
%         function resetProtocol(self)  % has to be public so WavesurferModel can call it
%             % Clears all aspects of the current protocol (i.e. the stuff
%             % that gets saved/loaded to/from the config file.  Idea here is
%             % to return the protocol properties stored in the model to a
%             % blank slate, so that we're sure no aspects of the old
%             % protocol get carried over when loading a new .cfg file.            
% %             self.Enabled=false;  % this doesn't seem right...
% %             self.TestPulser_=ws.TestPulser('Parent',self);
% %             self.ElectrodeManager_.resetProtocol();
%         end  % function
    end % methods
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.Acquisition.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = ws.system.Subsystem.propertyAttributes();
        end  % function
    end  % class methods block
    
end  % classdef
