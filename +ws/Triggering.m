classdef Triggering < ws.TriggeringSubsystem 
    
    properties (Access=protected, Transient=true)
        BuiltinTriggerDABSTask_
    end
        
    methods
        function self = Triggering(parent)
            self@ws.TriggeringSubsystem(parent);
        end  % function
                
%         function settings = packageCoreSettings(self)
%             settings=struct() ;
%             for i=1:length(self.CoreFieldNames_)
%                 fieldName = self.CoreFieldNames_{i} ;
%                 settings.(fieldName) = self.(fieldName) ;
%             end
%         end
        
        function setupBuiltinTriggerTask(self) 
            if isempty(self.BuiltinTriggerDABSTask_) ,
                self.BuiltinTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('WaveSurfer Built-in Trigger Task');  % on-demand DO task
                sweepTriggerTerminalName = sprintf('PFI%d',self.BuiltinTrigger.PFIID) ;
                self.BuiltinTriggerDABSTask_.createDOChan(self.BuiltinTrigger.DeviceName, sweepTriggerTerminalName);
                self.BuiltinTriggerDABSTask_.writeDigitalData(false);
            end
        end  % function
        
        function initializeFromMDFStructure(self,mdfStructure)
            % Set up the trigger sources (i.e. internal triggers) specified
            % in the MDF.
            
            % Read the specs out of the MDF structure
            triggerSourceSpecs = mdfStructure.triggerSource ;
            triggerDestinationSpecs = mdfStructure.triggerDestination ;

            % Deal with the device names, setting the WSM DeviceName if
            % it's not set yet.
            triggerSourceDeviceNames = { triggerSourceSpecs.DeviceName } ;
            triggerDestinationDeviceNames = { triggerDestinationSpecs.DeviceName } ;
            deviceNames = [ triggerSourceDeviceNames triggerDestinationDeviceNames ] ;
            uniqueDeviceNames=unique(deviceNames);
            if length(uniqueDeviceNames)>1 ,
                error('ws:MoreThanOneDeviceName', ...
                      'WaveSurfer only supports a single NI card at present.');                      
            end
            deviceName = uniqueDeviceNames{1} ;
            globalDeviceName = self.Parent.DeviceName ;
            if isempty(globalDeviceName) ,
                self.Parent.DeviceName = deviceName ;
            else
                if ~isequal(deviceName, globalDeviceName) ,
                    error('ws:TriggeringDeviceNameConflictsWithOtherDeviceNames', ...
                          'WaveSurfer only supports a single NI card at present.');
                end                      
            end
            
            % Set up the counter triggers specified in the MDF
            for i = 1:length(triggerSourceSpecs) ,
                % Create the trigger source, set params
                thisCounterTriggerSpec=triggerSourceSpecs(i);                
                counterID = thisCounterTriggerSpec.CounterID ;  % PFIID will be set automatically
                source = self.addCounterTrigger(counterID) ;
                if isempty(source) ,
                    error('ws:CantUseCounterID', ...
                          'Counter ID %d is either in use or not supported by the device', counterID);
                end
                source.Name = thisCounterTriggerSpec.Name ;
                %source.DeviceName=thisCounterTriggerSpec.DeviceName;
                %source.CounterID = thisCounterTriggerSpec.CounterID ;  % PFIID will be set automatically
                %source.PFIID = thisCounterTriggerSpec.CounterID + 12 ;  % the NI default
                source.RepeatCount = 1 ;
                source.Interval = 1 ;  % s
                if isfield(thisCounterTriggerSpec,'Edge') ,
                    source.Edge = lower(thisCounterTriggerSpec.Edge) ;
                else                    
                    source.Edge = 'rising' ;
                end
            end  % for loop
            
            % Set up the external triggers specified in the MDF
            for i = 1:length(triggerDestinationSpecs) ,
                % Create the trigger destination, set params
                thisExternalTriggerSpec = triggerDestinationSpecs(i) ;
                pfiID = thisExternalTriggerSpec.PFIID ;
                destination = self.addExternalTrigger(pfiID) ;
                if isempty(destination) ,
                    error('ws:CantUsePFIID', ...
                          'PFI%d is either in use or not supported by the device', pfiID);
                end                    
                destination.Name = thisExternalTriggerSpec.Name ;
                if isfield(thisExternalTriggerSpec,'Edge') ,
                    destination.Edge = lower(thisExternalTriggerSpec.Edge) ;
                else                    
                    destination.Edge = 'rising' ;
                end
            end  % for loop            
        end  % function        
    end  % public methods block
    
    methods (Access=protected)
        function teardownBuiltinTriggerTask_(self) 
            ws.utility.deleteIfValidHandle(self.BuiltinTriggerDABSTask_);  % have to delete b/c DABS task
            self.BuiltinTriggerDABSTask_ = [] ;
        end
    end
    
    methods
        function releaseHardwareResources(self)
            self.releaseTimedHardwareResources();
            % no untimed HW resources
        end  % function

        function releaseTimedHardwareResources(self)
            self.teardownBuiltinTriggerTask_();
        end  % function
        
        function delete(self)
            self.releaseHardwareResources();
        end  % function
                
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods
        function pulseBuiltinTrigger(self)
            % Produce a pulse on the master trigger, which will truly start things
            self.BuiltinTriggerDABSTask_.writeDigitalData(true);            
            %pause(0.010);  % TODO: get rid of once done debugging
            self.BuiltinTriggerDABSTask_.writeDigitalData(false);            
        end  % function
                
        function startingRun(self)
            self.setupBuiltinTriggerTask();            
        end  % function
        
        function startingSweep(self) %#ok<MANU>
            %self.setupInternalSweepBasedTriggers();
        end  % function

        function completingSweep(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();            
        end  % function
        
        function abortingSweep(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function completingRun(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function abortingRun(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
                
%         function triggerSourceDone(self,triggerSource)
%             % Called "from below" when the counter trigger task finishes
%             %fprintf('Triggering::triggerSourceDone()\n');
%             if self.StimulationTriggerScheme.IsInternal ,
%                 if triggerSource==self.StimulationTriggerScheme ,
%                     %self.IsStimulationCounterTriggerTaskRunning=false;
%                     self.Parent.internalStimulationCounterTriggerTaskComplete();
%                 end
%             end            
%         end  % function 

        function didSetDeviceName(self)
            deviceName = self.Parent.DeviceName ;
            
            schemes = self.Schemes ;
            nTriggers = length(schemes) ;            
            for i = 1:nTriggers ,
                trigger = schemes{i} ;
                trigger.DeviceName = deviceName ;
            end
            
            self.broadcast('Update');
        end

    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
%     methods (Access = protected)
%         function result = getUniqueInternalSweepBasedTriggersInOrderForStarting_(self)
%             % Just what it says on the tin.  For starting, want the acq
%             % trigger last so that the stim trigger can trigger off it if
%             % they're using the same source.  Result is a cell array.
%             triggerSchemes={self.StimulationTriggerScheme self.AcquisitionTriggerScheme};
%             isInternal=cellfun(@(scheme)(scheme.IsInternal),triggerSchemes);
%             internalTriggerSchemes=triggerSchemes(isInternal);
% 
%             % If more than one internal trigger, need to check whether
%             % their sources are identical.  If so, only want to return one,
%             % so we don't start an internal trigger twice.
%             if length(internalTriggerSchemes)>1 ,
%                 if self.StimulationTriggerScheme==self.AcquisitionTriggerScheme ,
%                     % We pick the acq one, even though it shouldn't matter 
%                     result=internalTriggerSchemes(2);
%                 else
%                     result=internalTriggerSchemes;
%                 end
%             else
%                 result=internalTriggerSchemes;
%             end
%         end  % function
%         
%         function teardownInternalSweepBasedTriggers(self)
% %             if self.ContinuousModeTriggerScheme.IsInternal ,
% %                 self.ContinuousModeTriggerScheme.clear();
% %             end
%             
%             triggerSchemes = self.getUniqueInternalSweepBasedTriggersInOrderForStarting_();
%             for idx = 1:numel(triggerSchemes)
%                 triggerSchemes{idx}.teardown();
%             end
%         end  % function
%     end
           
%     methods
%         function poll(self,timeSinceSweepStart)
% %             % Call the task to do the real work
% %             self.AcquisitionTriggerScheme.poll(timeSinceSweepStart);
% %             self.StimulationTriggerScheme.poll(timeSinceSweepStart);
%         end
%     end    
end
