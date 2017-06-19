classdef Ephys < ws.Subsystem
    properties (Dependent=true)
        TestPulseElectrodeCommandChannelName
        TestPulseElectrodeMonitorChannelName
        TestPulseElectrodeAmplitude
        TestPulseElectrodeIndex  % index of the currently selected test pulse electrode *within the array of all electrodes*
        TestPulseElectrodes
        TestPulseElectrodesCount
        TestPulseElectrodeMode  % mode of the current TP electrode (VC/CC)        
        AmplitudePerTestPulseElectrode
        TestPulseElectrode
        Monitor
        IsTestPulsing
    end
    
    properties (Access = protected)
        ElectrodeManager_
        TestPulser_
    end
    
    properties (Dependent=true, SetAccess=immutable)
        ElectrodeManager  % provides public access to ElectrodeManager_
        TestPulser  % provides public access to TestPulser_
    end    
      
    events
        UpdateTestPulser
    end
    
    methods
        function self = Ephys(parent)
            self@ws.Subsystem(parent) ;
            self.IsEnabled=true;            
            self.ElectrodeManager_ = ws.ElectrodeManager(self) ;
            self.TestPulser_ = ws.TestPulser(self) ;
            %self.TestPulser_.setNElectrodes_(self.ElectrodeManager_.TestPulseElectrodesCount) ;
        end
        
        function delete(self)
            self.TestPulser_ = [] ;
            self.ElectrodeManager_ = [] ;
        end
        
        function out = get.TestPulser(self)
            out=self.TestPulser_;
        end
        
        function out = get.ElectrodeManager(self)
            out=self.ElectrodeManager_;
        end
        
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

        function electrodeWasAdded(self,electrode)
            % Called by the ElectrodeManager when an electrode is added.
            % Currently, informs the TestPulser of the change.
            if ~isempty(self.TestPulser_)
                self.TestPulser_.electrodeWasAdded(electrode);
            end
        end

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

        function self=didSetAnalogChannelUnitsOrScales(self)
            testPulser=self.TestPulser;
            if ~isempty(testPulser) ,
                testPulser.didSetAnalogChannelUnitsOrScales();
            end            
        end       
        
        function isElectrodeMarkedForTestPulseMayHaveChanged(self)
            if ~isempty(self.TestPulser_)
                self.TestPulser_.isElectrodeMarkedForTestPulseMayHaveChanged();
            end
        end
                
        function startingRun(self)
            % Update all the gains and modes that are associated with smart
            % electrodes if checkbox is checked
            if self.ElectrodeManager_.DoTrodeUpdateBeforeRun
                self.ElectrodeManager_.updateSmartElectrodeGainsAndModes();
            end
        end
        
        function completingRun(self) %#ok<MANU>
        end
        
        function abortingRun(self) %#ok<MANU>
        end
        
        function didSetAcquisitionSampleRate(self,newValue)
            testPulser = self.TestPulser ;
            if ~isempty(testPulser) ,
                testPulser.didSetAcquisitionSampleRate(newValue) ;
            end
        end        
        
        function didSetIsInputChannelActive(self) 
            self.ElectrodeManager.didSetIsInputChannelActive() ;
            self.TestPulser.didSetIsInputChannelActive() ;
        end
        
        function didSetIsDigitalOutputTimed(self)
            self.ElectrodeManager.didSetIsDigitalOutputTimed() ;
        end
        
        function didChangeNumberOfInputChannels(self)
            self.ElectrodeManager.didChangeNumberOfInputChannels();
            self.TestPulser.didChangeNumberOfInputChannels();
        end        
        
        function didChangeNumberOfOutputChannels(self)
            self.ElectrodeManager.didChangeNumberOfOutputChannels();
            self.TestPulser.didChangeNumberOfOutputChannels();
        end        

        function didSetAnalogInputChannelName(self, didSucceed, oldValue, newValue)
            self.ElectrodeManager.didSetAnalogInputChannelName(didSucceed, oldValue, newValue) ;
        end        

        function didSetAnalogOutputChannelName(self, didSucceed, oldValue, newValue)
            self.ElectrodeManager.didSetAnalogOutputChannelName(didSucceed, oldValue, newValue) ;
        end        
    end  % methods block
    
    methods         
        function propNames = listPropertiesForHeader(self)
            propNamesRaw = listPropertiesForHeader@ws.Model(self) ;            
            % delete some property names that are defined in subclasses
            % that don't need to go into the header file
            propNames=setdiff(propNamesRaw, ...
                              {'TestPulser'}) ;
        end  % function 
    end  % public methods block    
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end
    end  % protected methods block
    
    methods (Access=protected)    
        function disableAllBroadcastsDammit_(self)
            self.TestPulser_.disableBroadcasts() ;
            self.ElectrodeManager_.disableBroadcasts() ;
        end
        
        function enableBroadcastsMaybeDammit_(self)
            self.ElectrodeManager_.enableBroadcastsMaybe() ;
            self.TestPulser_.enableBroadcastsMaybe() ;
        end
    end  % protected methods block

    methods
        function mimic(self, other)
            % Cause self to resemble other.
            
            % Disable broadcasts for speed
            %self.disableBroadcasts();
            self.ElectrodeManager.disableBroadcasts();
            self.TestPulser.disableBroadcasts();
            % Get the list of property names for this file type
            propertyNames = self.listPropertiesForPersistence();
            
            % Set each property to the corresponding one
            % all the "configurable" props in this class hold scalar
            % ws.Model objects, so this is simple
            for i = 1:length(propertyNames) ,
                thisPropertyName=propertyNames{i};
                if any(strcmp(thisPropertyName,{'ElectrodeManager_', 'TestPulser_'})) ,
                    source = other.(thisPropertyName) ;  % source as in source vs target, not as in source vs destination
                    target = self.(thisPropertyName) ;
                    target.mimic(source);  % all the props in this class hold scalar ws.Model objects
                else
                    if isprop(other,thisPropertyName)
                        source = other.getPropertyValue_(thisPropertyName) ;
                        self.setPropertyValue_(thisPropertyName, source) ;
                    end                    
                end
            end
            
            % Ensure self-consistency of self
            %self.TestPulser_.setNElectrodes_(self.ElectrodeManager_.TestPulseElectrodesCount) ;
            
            % Re-enable broadcasts
            self.TestPulser.enableBroadcastsMaybe();
            self.ElectrodeManager.enableBroadcastsMaybe();
            %self.enableBroadcastsMaybe();
            
            % Broadcast updates for sub-models and self, now that
            % everything is in sync, and should be self-consistent
            self.TestPulser.broadcast('Update');
            self.ElectrodeManager.broadcast('Update');
            %self.broadcast('Update');  % is this necessary?
        end  % function
        
        function didSetDeviceName(self, deviceName)
            %fprintf('ws.Triggering::didSetDevice() called\n') ;
            %dbstack
            self.TestPulser_.didSetDeviceName(deviceName) ;
        end        
    end
    
    methods (Access=protected)
        function value = getTestPulseElectrodeProperty_(self, propertyName)
            electrodeName = self.TestPulser_.ElectrodeName ;
            electrode = self.ElectrodeManager_.getElectrodeByName(electrodeName) ;
            if isempty(electrode) ,
                value = '' ;
            else
                value = electrode.(propertyName) ;
            end
        end
        
        function setTestPulseElectrodeProperty_(self, propertyName, newValue)
            electrodeName = self.TestPulser_.ElectrodeName ;
            electrode = self.ElectrodeManager_.getElectrodeByName(electrodeName) ;
            if ~isempty(electrode) ,
                electrode.(propertyName) = newValue ;
            end
        end
    end
    
    methods
        function result = get.TestPulseElectrodeCommandChannelName(self)
            result = self.getTestPulseElectrodeProperty_('CommandChannelName') ;
        end
        
        function result = get.TestPulseElectrodeMonitorChannelName(self)
            result = self.getTestPulseElectrodeProperty_('MonitorChannelName') ;
        end
        
        function result = get.TestPulseElectrodeAmplitude(self)
            result = self.getTestPulseElectrodeProperty_('TestPulseAmplitude') ;
        end
        
        function result=get.TestPulseElectrodes(self)
            electrodeManager=self.ElectrodeManager_;
            result=electrodeManager.TestPulseElectrodes;
        end

        function result=get.TestPulseElectrodesCount(self)
            electrodeManager=self.ElectrodeManager_ ;
            if isempty(electrodeManager) ,
                result=0;
            else
                result=electrodeManager.TestPulseElectrodesCount ;
            end
        end
        
        function result=get.AmplitudePerTestPulseElectrode(self)
            % Get the amplitudes of the test pulse for all the
            % marked-for-test-pulsing electrodes, as a double array.            
            electrodeManager=self.ElectrodeManager_;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %resultAsCellArray={testPulseElectrodes.TestPulseAmplitude};
            result=cellfun(@(electrode)(electrode.TestPulseAmplitude), ...
                           testPulseElectrodes);
        end  % function 
        
        function set.TestPulseElectrodeAmplitude(self, newValue)  % in units of the electrode command channel
            if ~isempty(self.TestPulser_.ElectrodeName) ,
                if ws.isString(newValue) ,
                    newValueAsDouble = str2double(newValue) ;
                elseif isnumeric(newValue) && isscalar(newValue) ,
                    newValueAsDouble = double(newValue) ;
                else
                    newValueAsDouble = nan ;  % isfinite(nan) is false
                end
                if isfinite(newValueAsDouble) ,
                    self.setTestPulseElectrodeProperty_('TestPulseAmplitude', newValueAsDouble) ;
                    self.TestPulser_.clearExistingSweepIfPresent_() ;
                else
                    self.broadcast('UpdateTestPulser') ;
                    error('ws:invalidPropertyValue', ...
                          'TestPulseElectrodeAmplitude must be a finite scalar');
                end
            end                
            self.broadcast('UpdateTestPulser') ;
        end  % function         
        
        function result=get.TestPulseElectrode(self)
            electrodeName = self.TestPulser_.ElectrodeName ;            
            electrodeManager = self.ElectrodeManager_ ;
            result = electrodeManager.getElectrodeByName(electrodeName) ;
        end  % function 
        
        function result = get.Monitor(self)
            currentElectrodeName = self.TestPulser_.ElectrodeName ;
            if isempty(currentElectrodeName)
                result = [] ; 
            else
                %electrodes = self.ElectrodeManager_.TestPulseElectrodes ;
                electrodeNames = self.ElectrodeManager_.TestPulseElectrodeNames ;
                isCurrentElectrode=cellfun(@(testElectrodeName)(isequal(currentElectrodeName, testElectrodeName)), electrodeNames) ;
                monitorPerElectrode = self.TestPulser_.getMonitorPerElectrode_() ;
                if isempty(monitorPerElectrode) ,
                    result = [] ;
                else
                    result = monitorPerElectrode(:,isCurrentElectrode) ;
                end
            end
        end  % function         
        
        function result = get.TestPulseElectrodeIndex(self)
            name = self.TestPulser_.ElectrodeName ;
            if isempty(name) ,
                result = zeros(1,0) ; 
            else
                result = self.ElectrodeManager_.getElectrodeIndexByName(name) ;
            end
        end  % function         
        
        function result = get.TestPulseElectrodeMode(self)
            electrodeName = self.TestPulser_.ElectrodeName ;
            if isempty(electrodeName) ,
                result = [] ;
            else
                result = self.ElectrodeManager_.getElectrodePropertyByName(electrodeName, 'Mode') ;
            end
        end  % function        
        
        function set.TestPulseElectrodeMode(self, newValue)            
            electrodeIndex = self.TestPulseElectrodeIndex ;  % index within all electrodes
            self.ElectrodeManager_.setElectrodeModeOrScaling(electrodeIndex, 'Mode', newValue) ;
        end  % function        
        
        function startTestPulsing_(self, fs)
            testPulseElectrodeIndex = self.TestPulseElectrodeIndex ;
            indexOfTestPulseElectrodeWithinTestPulseElectrodes = ...
                self.ElectrodeManager_.indexWithinTestPulseElectrodesFromElectrodeIndex(testPulseElectrodeIndex) ;
            testPulseElectrode = self.ElectrodeManager_.getElectrodeByIndex_(testPulseElectrodeIndex) ;
            
            amplitudePerTestPulseElectrode = self.AmplitudePerTestPulseElectrode ;
            
            nTestPulseElectrodes = self.ElectrodeManager_.TestPulseElectrodesCount ;
            gainOrResistanceUnitsPerTestPulseElectrode = self.getGainOrResistanceUnitsPerTestPulseElectrode() ;
            self.TestPulser_.start_(indexOfTestPulseElectrodeWithinTestPulseElectrodes, ...
                                    testPulseElectrode, ...
                                    amplitudePerTestPulseElectrode, ...
                                    fs, ...
                                    nTestPulseElectrodes, ...
                                    gainOrResistanceUnitsPerTestPulseElectrode) ;            
        end

        function stopTestPulsing_(self)
            self.TestPulser_.stop_() ;            
        end
        
        function result = get.IsTestPulsing(self)
            result = self.TestPulser_.IsRunning ;
        end
        
        function toggleIsTestPulsing(self)
            if self.IsTestPulsing , 
                self.stopTestPulsing_() ;
            else
                self.startTestPulsing_() ;
            end
        end
        
        function result = getGainOrResistancePerTestPulseElectrode(self)
            rawValue = self.TestPulser_.getGainOrResistancePerElectrode_() ;
            if isempty(rawValue) ,                
                nTestPulseElectrodes = self.ElectrodeManager_.TestPulseElectrodesCount ;
                result = nan(1,nTestPulseElectrodes) ;
            else
                result = rawValue ;
            end
        end

        function result = getGainOrResistanceUnitsPerTestPulseElectrode(self)
            result = self.TestPulser_.getGainOrResistanceUnitsPerElectrode_() ;
        end        
        
        function [gainOrResistance, gainOrResistanceUnits] = getGainOrResistancePerTestPulseElectrodeWithNiceUnits(self)
            rawGainOrResistance = self.getGainOrResistancePerTestPulseElectrode() ;
            rawGainOrResistanceUnits = self.getGainOrResistanceUnitsPerTestPulseElectrode() ;
            % [gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;  
            [gainOrResistanceUnits,gainOrResistance] = ...
                ws.convertDimensionalQuantityToEngineering(rawGainOrResistanceUnits,rawGainOrResistance) ;
        end
        
    end  % public methods block

end  % classdef
