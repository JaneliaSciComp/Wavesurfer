classdef LooperStimulation < ws.system.StimulationSubsystem   % & ws.mixin.DependentProperties
    % Stimulation subsystem in the looper process
    
    properties (Access = protected, Transient=true)
        TheUntimedDigitalOutputTask_ = []
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
                isDigitalChannelOnDemand = ~self.IsDigitalChannelTimed ;
                %untimedDigitalTerminalNames = self.DigitalTerminalNames(isDigitalChannelUntimed) ;
                digitalDeviceNames = self.DigitalDeviceNames ;
                onDemandDigitalDeviceNames = digitalDeviceNames(isDigitalChannelOnDemand) ;
                digitalTerminalIDs = self.DigitalTerminalIDs ;
                OnDemandDigitalTerminalIDs = digitalTerminalIDs(isDigitalChannelOnDemand) ;
                %untimedDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelUntimed) ;            
                self.TheUntimedDigitalOutputTask_ = ...
                    ws.ni.UntimedDigitalOutputTask(self, ...
                                                   'WaveSurfer Untimed Digital Output Task', ...
                                                   onDemandDigitalDeviceNames, ...
                                                   OnDemandDigitalTerminalIDs) ;
                % Set the outputs to the proper values, now that we have a task                               
                %fprintf('About to turn on/off on-demand digital channels\n');
                if any(isDigitalChannelOnDemand) ,
                    onDemandDigitalChannelState = self.DigitalOutputStateIfUntimed(isDigitalChannelOnDemand) ;
                    if ~isempty(onDemandDigitalChannelState) ,
                        self.TheUntimedDigitalOutputTask_.ChannelData = onDemandDigitalChannelState ;
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
                else
                    self.DigitalDeviceNames_ = self.DigitalDeviceNames_(isKeeper) ;
                    self.DigitalTerminalIDs_ = self.DigitalTerminalIDs_(isKeeper) ;
                    self.DigitalChannelNames_ = self.DigitalChannelNames_(isKeeper) ;
                    self.IsDigitalChannelTimed_ = self.IsDigitalChannelTimed_(isKeeper) ;
                    self.DigitalOutputStateIfUntimed_ = self.DigitalOutputStateIfUntimed_(isKeeper) ;
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
                    isDigitalChannelUntimed = ~self.IsDigitalChannelTimed_ ;
                    untimedDigitalChannelState = self.DigitalOutputStateIfUntimed_(isDigitalChannelUntimed) ;
                    if ~isempty(untimedDigitalChannelState) ,
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
