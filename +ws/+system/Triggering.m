classdef Triggering < ws.system.TriggeringSubsystem 
    
    properties (Access=protected, Transient=true)
        MasterTriggerDABSTask_
    end
        
    methods
        function self = Triggering(parent)
            self@ws.system.TriggeringSubsystem(parent);
        end  % function
        
        function initializeFromMDFStructure(self,mdfStructure)
            % Set up the trigger sources (i.e. internal triggers) specified
            % in the MDF.
            triggerSourceSpecs=mdfStructure.triggerSource;
            for idx = 1:length(triggerSourceSpecs) ,
                thisTriggerSourceSpec=triggerSourceSpecs(idx);
                
                % Create the trigger source, set params
                source = self.addNewTriggerSource() ;
                %source = ws.TriggerSource();                
                source.Name=thisTriggerSourceSpec.Name;
                source.DeviceName=thisTriggerSourceSpec.DeviceName;
                source.CounterID=thisTriggerSourceSpec.CounterID;                
                source.RepeatCount = 1;
                source.Interval = 1;  % s
                source.PFIID = thisTriggerSourceSpec.CounterID + 12;                
                source.Edge = 'rising';                                
                
                % add the trigger source to the subsystem
                %self.addTriggerSource(source);
                
                % If the first source, set things to point to it
                if idx==1 ,
                    self.AcquisitionTriggerSchemeIndex_ = 1 ;
                    self.StimulationTriggerSchemeIndex_ = 1 ;  
                    self.StimulationUsesAcquisitionTriggerScheme = true;
                end                    
            end  % for loop
            
            % Set up the trigger destinations (i.e. external triggers)
            % specified in the MDF.
            triggerDestinationSpecs=mdfStructure.triggerDestination;
            for idx = 1:length(triggerDestinationSpecs) ,
                thisTriggerDestinationSpec=triggerDestinationSpecs(idx);
                
                % Create the trigger destination, set params
                %destination = ws.TriggerDestination();
                destination = self.addNewTriggerDestination();
                destination.Name = thisTriggerDestinationSpec.Name;
                destination.DeviceName = thisTriggerDestinationSpec.DeviceName;
                destination.PFIID = thisTriggerDestinationSpec.PFIID;
                destination.Edge = lower(thisTriggerDestinationSpec.Edge);
                
                % add the trigger destination to the subsystem
                %self.addTriggerDestination(destination);
            end  % for loop
            
        end  % function
        
        function settings = packageCoreSettings(self)
            settings=struct() ;
            for i=1:length(self.CoreFieldNames_)
                fieldName = self.CoreFieldNames_{i} ;
                settings.(fieldName) = self.(fieldName) ;
            end
        end
        
        function setupMasterTriggerTask(self) 
            if isempty(self.MasterTriggerDABSTask_) ,
                self.MasterTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('Wavesurfer Master Trigger Task');
                self.MasterTriggerDABSTask_.createDOChan(self.Sources{1}.DeviceName, self.MasterTriggerPhysicalChannelName_);
                self.MasterTriggerDABSTask_.writeDigitalData(false);
            end
        end  % function

        function teardownMasterTriggerTask(self) 
            ws.utility.deleteIfValidHandle(self.MasterTriggerDABSTask_);  % have to delete b/c DABS task
            self.MasterTriggerDABSTask_ = [] ;
        end
        
        function releaseHardwareResources(self)
            self.teardownMasterTriggerTask();
        end  % function
        
        function delete(self)
            try
                self.releaseHardwareResources();
            catch me %#ok<NASGU>
                % Can't throw in the delete() function
            end                
        end  % function
                
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
    methods
        function pulseMasterTrigger(self)
            % Produce a pulse on the master trigger, which will truly start things
            self.MasterTriggerDABSTask_.writeDigitalData(true);            
            pause(0.010);  % TODO: get rid of once done debugging
            self.MasterTriggerDABSTask_.writeDigitalData(false);            
        end  % function
                
        function willPerformRun(self)
            self.setupMasterTriggerTask();            
        end  % function
        
        function willPerformSweep(self) %#ok<MANU>
            %self.setupInternalSweepBasedTriggers();
        end  % function

        function didCompleteSweep(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();            
        end  % function
        
        function didAbortSweep(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function didCompleteRun(self) %#ok<MANU>
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function didAbortRun(self) %#ok<MANU>
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
    
    methods (Access = protected)
        function result = getUniqueInternalSweepBasedTriggersInOrderForStarting_(self)
            % Just what it says on the tin.  For starting, want the acq
            % trigger last so that the stim trigger can trigger off it if
            % they're using the same source.  Result is a cell array.
            triggerSchemes={self.StimulationTriggerScheme self.AcquisitionTriggerScheme};
            isInternal=cellfun(@(scheme)(scheme.IsInternal),triggerSchemes);
            internalTriggerSchemes=triggerSchemes(isInternal);

            % If more than one internal trigger, need to check whether
            % their sources are identical.  If so, only want to return one,
            % so we don't start an internal trigger twice.
            if length(internalTriggerSchemes)>1 ,
                if self.StimulationTriggerScheme==self.AcquisitionTriggerScheme ,
                    % We pick the acq one, even though it shouldn't matter 
                    result=internalTriggerSchemes(2);
                else
                    result=internalTriggerSchemes;
                end
            else
                result=internalTriggerSchemes;
            end
        end  % function
        
        function teardownInternalSweepBasedTriggers(self)
%             if self.ContinuousModeTriggerScheme.IsInternal ,
%                 self.ContinuousModeTriggerScheme.clear();
%             end
            
            triggerSchemes = self.getUniqueInternalSweepBasedTriggersInOrderForStarting_();
            for idx = 1:numel(triggerSchemes)
                triggerSchemes{idx}.teardown();
            end
        end  % function
    end
           
%     methods
%         function poll(self,timeSinceSweepStart)
% %             % Call the task to do the real work
% %             self.AcquisitionTriggerScheme.poll(timeSinceSweepStart);
% %             self.StimulationTriggerScheme.poll(timeSinceSweepStart);
%         end
%     end    
end
