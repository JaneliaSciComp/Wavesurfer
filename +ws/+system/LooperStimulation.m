classdef LooperStimulation < ws.system.StimulationSubsystem   % & ws.mixin.DependentProperties
    % Stimulation subsystem in the looper process
    
    properties (Access = protected, Transient=true)
        TheUntimedDigitalOutputTask_ = []
        IsInUntimedDOTaskForEachUntimedDigitalChannel_
    end
    
    methods
        function self = LooperStimulation(parent)
            self@ws.system.StimulationSubsystem(parent) ;
        end
        
        function delete(self)
            self.releaseHardwareResources() ;
        end
        
        function debug(self) %#ok<MANU>
            keyboard
        end        
    end  % public methods block
    
    methods
        function acquireHardwareResources(self)            
            self.acquireOnDemandHardwareResources() ;  % LooperStimulation has only on-demand resources, not timed ones
        end
        
        function acquireOnDemandHardwareResources(self)
            %fprintf('LooperStimulation::acquireOnDemandHardwareResources()\n');
            if isempty(self.TheUntimedDigitalOutputTask_) ,
                %fprintf('the task is empty, so about to create a new one\n');
                
                % Get the digital device names and terminal IDs, other
                % things out of self
                deviceNameForEachDigitalChannel = self.DigitalDeviceNames ;
                terminalIDForEachDigitalChannel = self.DigitalTerminalIDs ;
                %if length(deviceNameForEachDigitalChannel) ~= length(terminalIDForEachDigitalChannel) ,
                %    self
                %    keyboard
                %end
                
                onDemandOutputStateForEachDigitalChannel = self.DigitalOutputStateIfUntimed ;
                isTerminalOvercommittedForEachDigitalChannel = self.Parent.IsDOChannelTerminalOvercommitted ;
                  % channels with out-of-range DIO terminal IDs are "overcommitted", too
                isTerminalUniquelyCommittedForEachDigitalChannel = ~isTerminalOvercommittedForEachDigitalChannel ;
                %nDIOTerminals = self.Parent.NDIOTerminals ;

                % Filter for just the on-demand ones
                isOnDemandForEachDigitalChannel = ~self.IsDigitalChannelTimed ;
                if any(isOnDemandForEachDigitalChannel) ,
                    deviceNameForEachOnDemandDigitalChannel = deviceNameForEachDigitalChannel(isOnDemandForEachDigitalChannel) ;
                    terminalIDForEachOnDemandDigitalChannel = terminalIDForEachDigitalChannel(isOnDemandForEachDigitalChannel) ;
                    outputStateForEachOnDemandDigitalChannel = onDemandOutputStateForEachDigitalChannel(isOnDemandForEachDigitalChannel) ;
                    isTerminalUniquelyCommittedForEachOnDemandDigitalChannel = isTerminalUniquelyCommittedForEachDigitalChannel(isOnDemandForEachDigitalChannel) ;
                else
                    deviceNameForEachOnDemandDigitalChannel = cell(1,0) ;  % want a length-zero row vector
                    terminalIDForEachOnDemandDigitalChannel = zeros(1,0) ;  % want a length-zero row vector
                    outputStateForEachOnDemandDigitalChannel = false(1,0) ;  % want a length-zero row vector
                    isTerminalUniquelyCommittedForEachOnDemandDigitalChannel = true(1,0) ;  % want a length-zero row vector
                end
                
                % The channels in the task are exactly those that are
                % uniquely committed.
                isInTaskForEachOnDemandDigitalChannel = isTerminalUniquelyCommittedForEachOnDemandDigitalChannel ;
                
                % Create the task
                deviceNamesInTask = deviceNameForEachOnDemandDigitalChannel(isInTaskForEachOnDemandDigitalChannel) ;
                terminalIDsInTask = terminalIDForEachOnDemandDigitalChannel(isInTaskForEachOnDemandDigitalChannel) ;
                self.TheUntimedDigitalOutputTask_ = ...
                    ws.ni.UntimedDigitalOutputTask(self, ...
                                                   'WaveSurfer Untimed Digital Output Task', ...
                                                   deviceNamesInTask, ...
                                                   terminalIDsInTask) ;
                self.IsInUntimedDOTaskForEachUntimedDigitalChannel_ = isInTaskForEachOnDemandDigitalChannel ;
                                               
                % Set the outputs to the proper values, now that we have a task                               
                %fprintf('About to turn on/off on-demand digital channels\n');
                if any(isInTaskForEachOnDemandDigitalChannel) ,                    
                    outputStateForEachChannelInOnDemandDigitalTask = ...
                        outputStateForEachOnDemandDigitalChannel(isInTaskForEachOnDemandDigitalChannel) ;
                    if ~isempty(outputStateForEachChannelInOnDemandDigitalTask) ,  % Isn't this redundant? -- ALT, 2016-02-02
                        self.TheUntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInOnDemandDigitalTask ;
                    end
                end                
            end
        end
        
        function releaseHardwareResources(self)
            self.releaseOnDemandHardwareResources() ;
            self.releaseTimedHardwareResources() ;
        end

        function releaseTimedHardwareResources(self) %#ok<MANU>
            % LooperStimulation has only on-demand resources, not timed ones
        end
        
        function releaseOnDemandHardwareResources(self)
            self.TheUntimedDigitalOutputTask_ = [];
            self.IsInUntimedDOTaskForEachUntimedDigitalChannel_ = [] ;   % for tidiness---this is meaningless if TheUntimedDigitalOutputTask_ is empty
        end

        function reacquireOnDemandHardwareResources(self)
            self.releaseOnDemandHardwareResources() ;
            self.acquireOnDemandHardwareResources() ;            
        end
        
        function reacquireHardwareResources(self)
            self.releaseHardwareResources() ;
            self.acquireHardwareResources() ;            
        end
        
        function didAddDOChannelInFrontend(self, ...
                                           channelNameForEachDOChannel, ...
                                           deviceNameForEachDOChannel, ...
                                           terminalIDForEachDOChannel, ...
                                           isTimedForEachDOChannel, ...
                                           onDemandOutputForEachDOChannel)
            self.didAddOrDeleteDOChannelsInFrontend_(channelNameForEachDOChannel, ...
                                                     deviceNameForEachDOChannel, ...
                                                     terminalIDForEachDOChannel, ...
                                                     isTimedForEachDOChannel, ...
                                                     onDemandOutputForEachDOChannel)
        end
        
        function didRemoveDigitalOutputChannelsInFrontend(self, ...
                                                          channelNameForEachDOChannel, ...
                                                          deviceNameForEachDOChannel, ...
                                                          terminalIDForEachDOChannel, ...
                                                          isTimedForEachDOChannel, ...
                                                          onDemandOutputForEachDOChannel)
            self.didAddOrDeleteDOChannelsInFrontend_(channelNameForEachDOChannel, ...
                                                     deviceNameForEachDOChannel, ...
                                                     terminalIDForEachDOChannel, ...
                                                     isTimedForEachDOChannel, ...
                                                     onDemandOutputForEachDOChannel)
        end
    end  % public methods block
       
    methods (Access=protected)
        function didAddOrDeleteDOChannelsInFrontend_(self, ...
                                                     channelNameForEachDOChannel, ...
                                                     deviceNameForEachDOChannel, ...
                                                     terminalIDForEachDOChannel, ...
                                                     isTimedForEachDOChannel, ...
                                                     onDemandOutputForEachDOChannel)
            self.DigitalChannelNames_ = channelNameForEachDOChannel ;
            self.DigitalDeviceNames_ = deviceNameForEachDOChannel ;
            self.DigitalTerminalIDs_ = terminalIDForEachDOChannel ;
            self.IsDigitalChannelTimed_ = isTimedForEachDOChannel ;
            self.DigitalOutputStateIfUntimed_ = onDemandOutputForEachDOChannel ;
            self.reacquireHardwareResources() ;
        end
    end
    
    methods    
%         function didRemoveDigitalOutputChannelsInFrontend(self, channelIndices)
%             nChannels = length(self.DigitalChannelNames) ;            
%             isKeeper = true(1,nChannels) ;
%             isKeeper(channelIndices) = false ;
%             if ~any(isKeeper) ,
%                 % special case so things stay row vectors
%                 self.DigitalDeviceNames_ = cell(1,0) ;
%                 self.DigitalTerminalIDs_ = zeros(1,0) ;
%                 self.DigitalChannelNames_ = cell(1,0) ;
%                 self.IsDigitalChannelTimed_ = true(1,0) ;
%                 self.DigitalOutputStateIfUntimed_ = false(1,0) ;     
%                 self.IsDigitalChannelMarkedForDeletion_ = false(1,0) ;     
%             else
%                 self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
%                 self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
%                 self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
%                 self.IsDigitalChannelTimed_ = self.IsDigitalChannelTimed_(isKeeper) ;
%                 self.DigitalOutputStateIfUntimed_ = self.DigitalOutputStateIfUntimed_(isKeeper) ;
%                 self.IsDigitalChannelMarkedForDeletion_ = self.IsDigitalChannelMarkedForDeletion_(isKeeper) ;
%             end
%             self.reacquireHardwareResources() ;
%         end
        
%         function didRemoveDigitalOutputChannelsInFrontendAlternateSeemsBad(self, indicesOfChannelsToBeDeleted)
%             % Delete just the indicated channels.  We take pains to
%             % preserve the IsMarkedForDeletion status of the surviving
%             % channels.  The primary use case of this is to sync up the
%             % Looper with the Frontend when the user deletes digital
%             % channels.
%             
%             % Get the current state of IsMarkedForDeletion, so that we can
%             % restore it for the surviving channels before we exit
%             isChannelMarkedForDeletionAtEntry = self.IsDigitalChannelMarkedForDeletion ;
%             
%             % Construct a logical array indicating which channels we're
%             % going to delete, as indicated by indicesOfChannelsToBeDeleted
%             nChannels = length(isChannelMarkedForDeletionAtEntry) ;
%             isToBeDeleted = false(1,nChannels) ;
%             isToBeDeleted(indicesOfChannelsToBeDeleted) = true ;
%             
%             % Mark the channels we want to delete, then delete them using
%             % the public interface
%             self.IsDigitalChannelMarkedForDeletion_ = isToBeDeleted ;
%             self.deleteMarkedDigitalChannels() ;
%             
%             % Now restore IsMarkedForDeletion for the surviving channels to
%             % the value they had on entry
%             wasDeleted = isToBeDeleted ;
%             wasKept = ~wasDeleted ;
%             isChannelMarkedForDeletionAtExit = isChannelMarkedForDeletionAtEntry(wasKept) ;
%             self.IsDigitalChannelMarkedForDeletion_ = isChannelMarkedForDeletionAtExit ;            
%         end
        
        function didSelectStimulusSequence(self, cycle)
            self.StimulusLibrary.SelectedOutputable = cycle;
        end  % function
        
    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end
    end  % protected methods block

    methods
        function singleDigitalOutputTerminalIDWasSetInFrontend(self, i, newValue)
            self.DigitalTerminalIDs_(i) = newValue ;
        end  % function
        
        function isDigitalChannelTimedWasSetInFrontend(self, newValue)
            self.IsDigitalChannelTimed_ = newValue ;
            self.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately
        end  % function
        
        function digitalOutputStateIfUntimedWasSetInFrontend(self, newValue)
            self.DigitalOutputStateIfUntimed_ = newValue ;
            if ~isempty(self.TheUntimedDigitalOutputTask_) ,
                isInUntimedDOTaskForEachUntimedDigitalChannel = self.IsInUntimedDOTaskForEachUntimedDigitalChannel_ ;
                isDigitalChannelUntimed = ~self.IsDigitalChannelTimed_ ;
                outputStateIfUntimedForEachDigitalChannel = self.DigitalOutputStateIfUntimed_ ;
                outputStateForEachUntimedDigitalChannel = outputStateIfUntimedForEachDigitalChannel(isDigitalChannelUntimed) ;
                outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDigitalChannel(isInUntimedDOTaskForEachUntimedDigitalChannel) ;
                if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
                    self.TheUntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInUntimedDOTask ;
                end
            end            
        end  % function        
    end
    
    methods (Access=protected)
%         function setIsDigitalChannelTimed_(self, newValue)
%             wasSet = setIsDigitalChannelTimed_@ws.system.StimulationSubsystem(self, newValue) ;
%             if wasSet ,
%                 self.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately
%             end  
%             %self.broadcast('DidSetIsDigitalChannelTimed');
%         end  % function
        
%         function setDigitalOutputStateIfUntimed_(self, newValue)
%             wasSet = setDigitalOutputStateIfUntimed_@ws.system.StimulationSubsystem(self, newValue) ;
%             if wasSet ,
%                 if ~isempty(self.TheUntimedDigitalOutputTask_) ,
%                     isInUntimedDOTaskForEachUntimedDigitalChannel = self.IsInUntimedDOTaskForEachUntimedDigitalChannel_ ;
%                     isDigitalChannelUntimed = ~self.IsDigitalChannelTimed_ ;
%                     outputStateIfUntimedForEachDigitalChannel = self.DigitalOutputStateIfUntimed_ ;
%                     outputStateForEachUntimedDigitalChannel = outputStateIfUntimedForEachDigitalChannel(isDigitalChannelUntimed) ;
%                     outputStateForEachChannelInUntimedDOTask = outputStateForEachUntimedDigitalChannel(isInUntimedDOTaskForEachUntimedDigitalChannel) ;
%                     if ~isempty(outputStateForEachChannelInUntimedDOTask) ,  % protects us against differently-dimensioned empties
%                         self.TheUntimedDigitalOutputTask_.ChannelData = outputStateForEachChannelInUntimedDOTask ;
%                     end
%                 end
%             end
%             %self.broadcast('DidSetDigitalOutputStateIfUntimed');
%         end  % function
        
%         function addDigitalChannel_(self)
%             fprintf('LooperStimulation::addDigitalChannel_\n') ;
%             addDigitalChannel_@ws.system.StimulationSubsystem(self) ;
%             digitalChannelNames = self.DigitalChannelNames
%             digitalTerminalIDs = self.DigitalTerminalIDs            
%             self.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately
%             fprintf('About to exit LooperStimulation::addDigitalChannel_\n') ;
%         end
%         
%         function removeDigitalChannel_(self, channelIndex)
%             removeDigitalChannel_@ws.system.StimulationSubsystem(self, channelIndex) ;
%             self.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately
%         end
    end
    
    methods
        function setDigitalOutputStateIfUntimedQuicklyAndDirtily(self, newValue)
            % This method does no error checking, for minimum latency
            self.TheUntimedDigitalOutputTask_.setChannelDataQuicklyAndDirtily(newValue) ;
        end
        
        function didSetDeviceNameInFrontend(self)
            deviceName = self.Parent.DeviceName ;
            self.AnalogDeviceNames_(:) = {deviceName} ;            
            self.DigitalDeviceNames_(:) = {deviceName} ;
        end
        
        function mimickingWavesurferModel_(self)
            deviceName = self.Parent.DeviceName ;
            self.AnalogDeviceNames_(:) = {deviceName} ;            
            self.DigitalDeviceNames_(:) = {deviceName} ;
        end        
    end
end  % classdef
