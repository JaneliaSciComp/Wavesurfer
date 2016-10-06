classdef Acquisition < ws.AcquisitionSubsystem
    
    properties (Access=protected, Transient=true)
        AnalogScalingCoefficientsCache_  % a cache of the analog input scaling coefficients, populated at the start of a run, set to empty at end of run
    end
    
    methods
        function self = Acquisition(parent)
            self@ws.AcquisitionSubsystem(parent);
        end
        
%         function initializeFromMDFStructure(self, mdfStructure)
%             terminalNamesWithDeviceName = mdfStructure.physicalInputChannelNames ;  % these should be of the form 'Dev1/ao0' or 'Dev1/line3'            
%             
%             if ~isempty(terminalNamesWithDeviceName) ,
%                 channelNames = mdfStructure.inputChannelNames;
% 
%                 % Deal with the device names, setting the WSM DeviceName if
%                 % it's not set yet.
%                 deviceNames = ws.deviceNamesFromTerminalNames(terminalNamesWithDeviceName);
%                 uniqueDeviceNames=unique(deviceNames);
%                 if length(uniqueDeviceNames)>1 ,
%                     error('ws:MoreThanOneDeviceName', ...
%                           'WaveSurfer only supports a single NI card at present.');                      
%                 end
%                 deviceName = uniqueDeviceNames{1} ;                
%                 if isempty(self.Parent.DeviceName) ,
%                     self.Parent.DeviceName = deviceName ;
%                 end
% 
%                 % Get the channel IDs
%                 terminalIDs = ws.terminalIDsFromTerminalNames(terminalNamesWithDeviceName);
%                 
%                 % Figure out which are analog and which are digital
%                 channelTypes = ws.channelTypesFromTerminalNames(terminalNamesWithDeviceName);
%                 isAnalog = strcmp(channelTypes,'ai');
%                 isDigital = ~isAnalog;
% 
%                 % Sort the channel names, etc
%                 %analogDeviceNames = deviceNames(isAnalog) ;
%                 %digitalDeviceNames = deviceNames(isDigital) ;
%                 analogTerminalIDs = terminalIDs(isAnalog) ;
%                 digitalTerminalIDs = terminalIDs(isDigital) ;            
%                 analogChannelNames = channelNames(isAnalog) ;
%                 digitalChannelNames = channelNames(isDigital) ;
% 
%                 % add the analog channels
%                 nAnalogChannels = length(analogChannelNames);
%                 for i = 1:nAnalogChannels ,
%                     self.addAnalogChannel() ;
%                     indexOfChannelInSelf = self.NAnalogChannels ;
%                     self.setSingleAnalogChannelName(indexOfChannelInSelf, analogChannelNames{i}) ;                    
%                     self.setSingleAnalogTerminalID(indexOfChannelInSelf, analogTerminalIDs(i)) ;
%                 end
%                 
%                 % add the digital channels
%                 nDigitalChannels = length(digitalChannelNames);
%                 for i = 1:nDigitalChannels ,
%                     self.Parent.addDIChannel() ;
%                     indexOfChannelInSelf = self.NDigitalChannels ;
%                     self.setSingleDigitalChannelName(indexOfChannelInSelf, digitalChannelNames{i}) ;
%                     self.Parent.setSingleDIChannelTerminalID(indexOfChannelInSelf, digitalTerminalIDs(i)) ;
%                 end                
%             end
%         end  % function
        
%         function settings = packageCoreSettings(self)
%             settings=struct() ;
%             for i=1:length(self.CoreFieldNames_)
%                 fieldName = self.CoreFieldNames_{i} ;
%                 settings.(fieldName) = self.(fieldName) ;
%             end
%         end        
    end  % methods block    
    
    
    methods
        function startingRun(self)
            %fprintf('Acquisition::startingRun()\n');
            %errors = [];
            %abort = false;
            
%             if isempty(self.TriggerScheme) ,
%                 error('wavesurfer:acquisitionsystem:invalidtrigger', ...
%                       'The acquisition trigger scheme can not be empty when the system is enabled.');
%             end
%             
%             if isempty(self.TriggerScheme.Target) ,
%                 error('wavesurfer:acquisitionsystem:invalidtrigger', ...
%                       'The acquisition trigger scheme target can not be empty when the system is enabled.');
%             end
            
            wavesurferModel = self.Parent ;
            
%             % Make the NI daq task, if don't have it already
%             self.acquireHardwareResources_();

%             % Set up the task triggering
%             self.AnalogInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
%             self.AnalogInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
%             self.DigitalInputTask_.TriggerPFIID = self.TriggerScheme.Target.PFIID;
%             self.DigitalInputTask_.TriggerEdge = self.TriggerScheme.Target.Edge;
%             
%             % Set for finite vs. continous sampling
%             if wavesurferModel.AreSweepsContinuous ,
%                 self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
%                 self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
%             else
%                 self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
%                 self.AnalogInputTask_.AcquisitionDuration = self.Duration ;
%                 self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
%                 self.DigitalInputTask_.AcquisitionDuration = self.Duration ;
%             end

            % Check that there's at least one active input channel
            NActiveAnalogChannels = sum(self.IsAnalogChannelActive);
            NActiveDigitalChannels = sum(self.IsDigitalChannelActive);
            NActiveInputChannels = NActiveAnalogChannels + NActiveDigitalChannels ;
            if NActiveInputChannels==0 ,
                error('wavesurfer:NoActiveInputChannels' , ...
                      'There must be at least one active input channel to perform a run');
            end

            % Dimension the cache that will hold acquired data in main memory
            if self.NDigitalChannels<=8
                dataType = 'uint8';
            elseif self.NDigitalChannels<=16
                dataType = 'uint16';
            else %self.NDigitalChannels<=32
                dataType = 'uint32';
            end
            if wavesurferModel.AreSweepsContinuous ,
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.SampleRate) ;
                self.RawAnalogDataCache_ = zeros(nScans,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(nScans,min(1,NActiveDigitalChannels),dataType);
            elseif wavesurferModel.AreSweepsFiniteDuration ,
                self.RawAnalogDataCache_ = zeros(self.ExpectedScanCount,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(self.ExpectedScanCount,min(1,NActiveDigitalChannels),dataType);
            else
                % Shouldn't ever happen
                self.RawAnalogDataCache_ = [];                
                self.RawDigitalDataCache_ = [];                
            end
            
%             % Arm the AI task
%             self.AnalogInputTask_.arm();
%             self.DigitalInputTask_.arm();
        end  % function
        
%         function completingRun(self)
%             self.AnalogScalingCoefficientsCache_ = [] ;
%         end
%         
%         function stoppingRun(self) 
%             self.AnalogScalingCoefficientsCache_ = [] ;
%         end
%         
%         function abortingRun(self)
%             % Called if a failure occurred during startingRun() for subsystems
%             % that have already passed startingRun() to clean up, and called fater
%             % abortingSweep().
%             
%             % This code MUST be exception free.
%             self.AnalogScalingCoefficientsCache_ = [] ;
%         end
        
        function wasSet = setSingleDigitalTerminalID_(self, i, newValue)
            % This should only be called from the parent
            if 1<=i && i<=self.NDigitalChannels && isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) ,
                newValueAsDouble = double(newValue) ;
                if newValueAsDouble>=0 && newValueAsDouble==round(newValueAsDouble) ,
                    self.DigitalTerminalIDs_(i) = newValueAsDouble ;
                    wasSet = true ;
                else
                    wasSet = false ;
                end
            else
                wasSet = false ;
            end                
            %self.Parent.didSetDigitalInputTerminalID();
        end
    end  % public methods block

    methods (Access=protected)
        function value = getAnalogChannelScales_(self)
            wavesurferModel=self.Parent;
            if isempty(wavesurferModel) ,
                ephys=[];
            else
                ephys=wavesurferModel.Ephys;
            end
            if isempty(ephys) ,
                electrodeManager=[];
            else
                electrodeManager=ephys.ElectrodeManager;
            end
            if isempty(electrodeManager) ,
                value=self.AnalogChannelScales_;
            else
                analogChannelNames=self.AnalogChannelNames;
                [channelScalesFromElectrodes, ...
                 isChannelScaleEnslaved] = ...
                    electrodeManager.getMonitorScalingsByName(analogChannelNames);
                value=ws.fif(isChannelScaleEnslaved,channelScalesFromElectrodes,self.AnalogChannelScales_);
            end
        end
    end  % methods block    
    
    methods
        function addDigitalChannel_(self)
            %deviceName = self.Parent.DeviceName ;
            
            %newChannelDeviceName = deviceName ;
            freeTerminalIDs = self.Parent.freeDigitalTerminalIDs() ;
            if isempty(freeTerminalIDs) ,
                return  % can't add a new one, because no free IDs
            else
                newTerminalID = freeTerminalIDs(1) ;
            end
            newChannelName = sprintf('P0.%d',newTerminalID) ;
            %newChannelName = newChannelPhysicalName ;
            
            %self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {newChannelDeviceName} ] ;
            self.DigitalTerminalIDs_ = [self.DigitalTerminalIDs_ newTerminalID] ;
            %self.DigitalTerminalNames_ =  [self.DigitalTerminalNames_ {newChannelPhysicalName}] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            self.IsDigitalChannelActive_ = [  self.IsDigitalChannelActive_ true ];
            self.IsDigitalChannelMarkedForDeletion_ = [  self.IsDigitalChannelMarkedForDeletion_ false ];
            %self.syncIsDigitalChannelTerminalOvercommitted_() ;
            
            self.updateActiveChannelIndexFromChannelIndex_() ;
            %self.Parent.didAddDigitalInputChannel() ;
            %self.broadcast('DidChangeNumberOfChannels');            
        end  % function
        
        function wasDeleted = deleteMarkedDigitalChannels_(self)
            isToBeDeleted = self.IsDigitalChannelMarkedForDeletion_ ;
            %channelNamesToDelete = self.DigitalChannelNames_(isToBeDeleted) ;            
            if all(isToBeDeleted) ,
                % Special case so things stay row vectors
                %self.DigitalDeviceNames_ = cell(1,0) ;
                self.DigitalTerminalIDs_ = zeros(1,0) ;
                self.DigitalChannelNames_ = cell(1,0) ;
                self.IsDigitalChannelActive_ = true(1,0) ;
                self.IsDigitalChannelMarkedForDeletion_ = false(1,0) ;
            else
                isKeeper = ~isToBeDeleted ;
                %self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
                self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                self.IsDigitalChannelActive_ = self.IsDigitalChannelActive_(isKeeper) ;
                self.IsDigitalChannelMarkedForDeletion_ = self.IsDigitalChannelMarkedForDeletion_(isKeeper) ;
            end
            self.updateActiveChannelIndexFromChannelIndex_() ;
            wasDeleted = isToBeDeleted ;
%             %self.syncIsDigitalChannelTerminalOvercommitted_() ;
%             self.Parent.didDeleteDigitalInputChannels(channelNamesToDelete) ;
        end  % function
        
        function didSetDeviceName(self)
            %deviceName = self.Parent.DeviceName ;
            %self.AnalogDeviceNames_(:) = {deviceName} ;
            %self.DigitalDeviceNames_(:) = {deviceName} ;            
            self.broadcast('Update');
        end
        
        function cacheAnalogScalingCoefficients_(self, analogScalingCoefficients) 
            self.AnalogScalingCoefficientsCache_ = analogScalingCoefficients ;
        end
        
        function clearAnalogScalingCoefficientsCache_(self) 
            self.AnalogScalingCoefficientsCache_ = [] ;
        end
        
    end

    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods (Access=protected)
        function result = getAnalogScalingCoefficients_(self)
            result = self.AnalogScalingCoefficientsCache_ ;
        end
    end  % protected methods block
    
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.enableBroadcastsMaybe() ;
        end
    end  % protected methods block
    
end  % classdef
