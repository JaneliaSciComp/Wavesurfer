classdef Ephys < ws.Subsystem
    properties (Access = protected)
        ElectrodeManager_
        TestPulser_
    end
    
    properties (Dependent=true, SetAccess=immutable)
        ElectrodeManager  % provides public access to ElectrodeManager_
        TestPulser  % provides public access to TestPulser_
    end    
      
    methods
        function self = Ephys(parent)
            self@ws.Subsystem(parent) ;
            self.IsEnabled=true;            
            self.ElectrodeManager_ = ws.ElectrodeManager(self) ;
            self.TestPulser_ = ws.TestPulser(self) ;
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
        
    end  % public methods block

end  % classdef
