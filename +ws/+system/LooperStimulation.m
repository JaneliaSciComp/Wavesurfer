classdef LooperStimulation < ws.system.StimulationSubsystem   % & ws.mixin.DependentProperties
    % Stimulation subsystem in the looper process
    
    properties (Access = protected, Transient=true)
        TheUntimedDigitalOutputTask_ = []
        IsTerminalInUntimedDigitalOutputTask_
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
                
                % Get the digital device names and terminal IDs
                digitalDeviceNames = self.DigitalDeviceNames ;
                digitalTerminalIDs = self.DigitalTerminalIDs ;

                % Filter for just the on-demand ones
                isOnDemand = ~self.IsDigitalChannelTimed ;
                %deviceNames2 = digitalDeviceNames(isOnDemand) ;
                %terminalIDs2 = digitalTerminalIDs(isOnDemand) ;
                
                % Filter out channels with terminal IDs that are
                % out-of-range.
                nDIOTerminals = self.Parent.NDIOTerminals ;
                isInRange = (0<=digitalTerminalIDs) & (digitalTerminalIDs<nDIOTerminals) ;
                %deviceNames3 = deviceNames2(isInRange) ;
                %terminalIDs3 = terminalIDs2(isInRange) ;
                
                % Filter out channels with terminal IDs that are
                % overcommited.
                %
                % Note that we don't check for collisions with DIO
                % terminals that are timed, or with ones that are being
                % used as (timed) digital *inputs*.  But that should be OK,
                % in the sense of not leading to errors for conflicts that
                % get resolved before they start a run.  You could argue
                % that us setting the values on in-conflict channels will 
                % surprise the user, but we'll live with that for now.
                nOccurancesOfTerminal = ws.nOccurancesOfID(digitalTerminalIDs) ;
                isTerminalIDUnique = (nOccurancesOfTerminal==1) ;                
                
                % And all the filters together
                isTerminalInTask = isOnDemand & isInRange & isTerminalIDUnique ;
                self.IsTerminalInUntimedDigitalOutputTask_ = isTerminalInTask ;
                
                % Create the task
                deviceNamesInTask = digitalDeviceNames(isTerminalInTask) ;
                terminalIDsInTask = digitalTerminalIDs(isTerminalInTask) ;
                self.TheUntimedDigitalOutputTask_ = ...
                    ws.ni.UntimedDigitalOutputTask(self, ...
                                                   'WaveSurfer Untimed Digital Output Task', ...
                                                   deviceNamesInTask, ...
                                                   terminalIDsInTask) ;
                                               
                % Set the outputs to the proper values, now that we have a task                               
                %fprintf('About to turn on/off on-demand digital channels\n');
                if any(isTerminalInTask) ,
                    channelStateForEachTerminalInTask = self.DigitalOutputStateIfUntimed(isTerminalInTask) ;
                    if ~isempty(channelStateForEachTerminalInTask) ,  % Isn't this redundant? -- ALT, 2016-02-02
                        self.TheUntimedDigitalOutputTask_.ChannelData = channelStateForEachTerminalInTask ;
                    end
                end                
            end
        end
        
        function releaseHardwareResources(self)
            self.releaseOnDemandHardwareResources() ;  % LooperStimulation has only on-demand resources, not timed ones
            self.releaseTimedHardwareResources() ;
        end

        function releaseTimedHardwareResources(self) %#ok<MANU>
            % LooperStimulation has only on-demand resources, not timed ones
        end
        
        function releaseOnDemandHardwareResources(self)
            self.TheUntimedDigitalOutputTask_ = [];            
        end
        
        function reacquireHardwareResources(self) 
            self.releaseHardwareResources() ;
            self.acquireHardwareResources() ;            
        end
        
        function didAddDigitalChannelInFrontend(self, newChannelName, newChannelDeviceName, newTerminalID, isNewChannelTimed, newChannelStateIfUntimed)
            self.DigitalDeviceNames_ = [self.DigitalDeviceNames_ {newChannelDeviceName} ] ;
            self.DigitalTerminalIDs_ = [self.DigitalTerminalIDs_ newTerminalID] ;
            self.DigitalChannelNames_ = [self.DigitalChannelNames_ {newChannelName}] ;
            self.IsDigitalChannelTimed_ = [ self.IsDigitalChannelTimed_ isNewChannelTimed  ] ;
            self.DigitalOutputStateIfUntimed_ = [ self.DigitalOutputStateIfUntimed_ newChannelStateIfUntimed ] ;
            self.IsDigitalChannelMarkedForDeletion_ = [ self.IsDigitalChannelMarkedForDeletion_ false ] ;
            self.reacquireHardwareResources() ;
        end
        
        function didRemoveDigitalChannelInFrontend(self, channelIndex)
            nChannels = length(self.DigitalTerminalIDs) ;
            if 1<=channelIndex && channelIndex<=nChannels ,
                %channelName = self.AnalogChannelNames_{channelIndex} ;
                isKeeper = true(1,nChannels) ;
                isKeeper(channelIndex) = false ;
                if ~any(isKeeper) ,
                    % special case so things stay row vectors
                    self.DigitalDeviceNames_ = cell(1,0) ;
                    self.DigitalTerminalIDs_ = zeros(1,0) ;
                    self.DigitalChannelNames_ = cell(1,0) ;
                    self.IsDigitalChannelTimed_ = true(1,0) ;
                    self.DigitalOutputStateIfUntimed_ = false(1,0) ;     
                    self.IsDigitalChannelMarkedForDeletion_ = false(1,0) ;     
                else
                    self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                    self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
                    self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                    self.IsDigitalChannelTimed_ = self.IsDigitalChannelTimed_(isKeeper) ;
                    self.DigitalOutputStateIfUntimed_ = self.DigitalOutputStateIfUntimed_(isKeeper) ;
                    self.IsDigitalChannelMarkedForDeletion_ = self.IsDigitalChannelMarkedForDeletion_(isKeeper) ;
                end
                self.reacquireHardwareResources() ;
            end            
        end
        
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
    
    methods (Access=protected)
        function setSingleDigitalTerminalID_(self, i, newValue)
            wasSet = setSingleDigitalTerminalID_@ws.system.StimulationSubsystem(self, i, newValue) ;
            % If the setting was valid, and the channel is on-demand, we
            % need to release and re-acquire the hardware resources.
            if wasSet && ~self.IsDigitalChannelTimed(i) ,
                self.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately
            end
        end  % function

        function setIsDigitalChannelTimed_(self, newValue)
            wasSet = setIsDigitalChannelTimed_@ws.system.StimulationSubsystem(self, newValue) ;
            if wasSet ,
                self.reacquireHardwareResources() ;  % this clears the existing task, makes a new task, and sets everything appropriately
            end  
            %self.broadcast('DidSetIsDigitalChannelTimed');
        end  % function
        
        function setDigitalOutputStateIfUntimed_(self, newValue)
            wasSet = setDigitalOutputStateIfUntimed_@ws.system.StimulationSubsystem(self, newValue) ;
            if wasSet ,
                if ~isempty(self.TheUntimedDigitalOutputTask_) ,
                    isTerminalInUntimedDigitalOutputTask = self.IsTerminalInUntimedDigitalOutputTask_ ;
                    %isDigitalChannelUntimed = ~self.IsDigitalChannelTimed_ ;
                    untimedDigitalChannelState = self.DigitalOutputStateIfUntimed_(isTerminalInUntimedDigitalOutputTask) ;
                    if ~isempty(untimedDigitalChannelState) ,  % protects us against differently-dimensioned empties
                        self.TheUntimedDigitalOutputTask_.ChannelData = untimedDigitalChannelState ;
                    end
                end
            end
            %self.broadcast('DidSetDigitalOutputStateIfUntimed');
        end  % function
        
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
    end
end  % classdef
