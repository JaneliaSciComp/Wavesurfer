classdef Triggering < ws.system.TriggeringSubsystem 
    
    properties (Access=protected, Transient=true)
        MasterTriggerDABSTask_
    end
    
    properties (Access=protected, Constant=true)
        MasterTriggerPhysicalChannelName_ = 'pfi8'
        MasterTriggerPFIID_ = 8
        MasterTriggerEdge_ = ws.ni.TriggerEdge.Rising
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
                source.Edge = ws.ni.TriggerEdge.Rising;                                
                
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
                destination.Edge = ws.ni.TriggerEdge.(thisTriggerDestinationSpec.Edge);
                
                % add the trigger destination to the subsystem
                %self.addTriggerDestination(destination);
            end  % for loop
            
        end  % function
        
        function setupMasterTriggerTask(self) 
            if isempty(self.MasterTriggerDABSTask_) ,
                self.MasterTriggerDABSTask_ = ws.dabs.ni.daqmx.Task('Wavesurfer Master Trigger Task');
                self.MasterTriggerDABSTask_.createDOChan(self.Sources(1).DeviceName, self.MasterTriggerPhysicalChannelName_);
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
            self.MasterTriggerDABSTask_.writeDigitalData(false);            
        end  % function
                
        function willPerformRun(self)
            self.setupMasterTriggerTask();            
        end  % function
        
        function willPerformSweep(self)
            %self.setupInternalSweepBasedTriggers();
        end  % function

        function didCompleteSweep(self)
            %self.teardownInternalSweepBasedTriggers();            
        end  % function
        
        function didAbortSweep(self)
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function didCompleteRun(self)
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function didAbortRun(self)
            %self.teardownInternalSweepBasedTriggers();
        end  % function
        
        function stimulusMapDurationPrecursorMayHaveChanged(self)
            wavesurferModel=self.Parent;
            if ~isempty(wavesurferModel) ,
                wavesurferModel.stimulusMapDurationPrecursorMayHaveChanged();
            end
        end  % function        
        
        function willSetNSweepsPerRun(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetNSweepsPerRun(self)
            self.syncTriggerSourcesFromTriggeringState_();            
        end  % function        
        
        function willSetAcquisitionDuration(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function

        function didSetAcquisitionDuration(self)
            self.syncTriggerSourcesFromTriggeringState_();            
        end  % function        
        
        function willSetIsSweepBased(self)
            % Have to release the relvant parts of the trigger scheme
            self.releaseCurrentTriggerSources_();
        end  % function
        
        function didSetIsSweepBased(self)
            %fprintf('Triggering::didSetIsSweepBased()\n');
            self.syncTriggerSourcesFromTriggeringState_();
            %self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();
            self.stimulusMapDurationPrecursorMayHaveChanged();  % Have to do b/c changing this can change StimulationUsesAcquisitionTriggerScheme
            %self.syncIntervalAndRepeatCountListeners_();
        end  % function 
        
        function triggerSourceDone(self,triggerSource)
            % Called "from below" when the counter trigger task finishes
            %fprintf('Triggering::triggerSourceDone()\n');
            if self.StimulationTriggerScheme.IsInternal ,
                if triggerSource==self.StimulationTriggerScheme ,
                    %self.IsStimulationCounterTriggerTaskRunning=false;
                    self.Parent.internalStimulationCounterTriggerTaskComplete();
                end
            end            
        end  % function 
    end  % methods block
    
    methods (Access = protected)
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end  % protected methods block
    
    methods (Access = protected)
        function setStimulationUsesAcquisitionTriggerScheme_(self,newValue)      
            if ws.utility.isASettableValue(newValue) ,
                if self.Parent.IsSweepBased ,
                    % overridden by IsSweepBased, do nothing
                else                    
                    if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && (newValue==1 || newValue==0))) ,
                        self.StimulationUsesAcquisitionTriggerScheme_ = logical(newValue) ;
                        %self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();
                        self.stimulusMapDurationPrecursorMayHaveChanged();
                    else
                        error('most:Model:invalidPropVal', ...
                              'StimulationUsesAcquisitionTriggerScheme must be a scalar, and must be logical, 0, or 1');
                    end
                end
            end
            self.broadcast('Update');            
        end  % function
        
        function value=getStimulationUsesAcquisitionTriggerScheme_(self)
            parent = self.Parent ;
            if ~isempty(parent) && isvalid(parent) && parent.IsSweepBased ,
                value = true ;
            else
                value = getStimulationUsesAcquisitionTriggerScheme_@ws.system.TriggeringSubsystem(self) ;
            end
        end  % function        
        
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
    
    methods
%         function willSetAcquisitionTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             % Have to release the relevant parts of the trigger scheme
%             self.releaseCurrentTriggerSources_();
%         end  % function
% 
%         function didSetAcquisitionTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             self.syncTriggerSourcesFromTriggeringState_();
%             %self.syncStimulationTriggerSchemeToAcquisitionTriggerScheme_();
%         end  % function
        
%         function willSetContinuousModeTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             % Have to release the relvant parts of the trigger scheme
%             self.releaseCurrentTriggerSources_();
%         end  % function
% 
%         function didSetContinuousModeTriggerSchemeTarget(self,broadcaster,eventName,propertyName,source,event) %#ok<INUSD>
%             self.syncTriggerSourcesFromTriggeringState_();
%         end  % function
    end
       
    methods (Access=protected)
%         function syncStimulationTriggerSchemeToAcquisitionTriggerScheme_(self) %#ok<MANU>
%             % This does nothing now, b/c the getter for
%             % StimulationTriggerScheme now simply returns the
%             % AcquisitionTriggerScheme if
%             % StimulationUsesAcquisitionTriggerScheme is true.
%             % This has the advantage the that stim trigger scheme settings
%             % are simply shadowed, not overwritten.
%             
% %             if self.StimulationUsesAcquisitionTriggerScheme ,
% %                 self.StimulationTriggerScheme = self.AcquisitionTriggerScheme;
% %             end
%         end  % function
            
        function releaseCurrentTriggerSources_(self)
            if self.AcquisitionTriggerScheme.IsInternal ,
                %if self.AcquisitionUsesASAPTriggering ,
                    self.AcquisitionTriggerScheme.releaseInterval();
                    self.AcquisitionTriggerScheme.releaseRepeatCount();
                %else
                %    self.AcquisitionTriggerScheme.releaseLowerLimitOnInterval();
                %    self.AcquisitionTriggerScheme.releaseRepeatCount();
                %end
            end
        end  % function
        
        function syncTriggerSourcesFromTriggeringState_(self)
            if self.AcquisitionTriggerScheme.IsInternal ,
                %if self.AcquisitionUsesASAPTriggering ,
                    %self.AcquisitionTriggerScheme.releaseLowerLimitOnInterval();
                    self.AcquisitionTriggerScheme.overrideInterval(0.01);
                    self.AcquisitionTriggerScheme.overrideRepeatCount(1);
                %else
                %    self.AcquisitionTriggerScheme.releaseInterval();
                %    self.AcquisitionTriggerScheme.placeLowerLimitOnInterval( ...
                %        self.Parent.Acquisition.Duration+self.MinDurationBetweenSweepsIfNotASAP );
                %    self.AcquisitionTriggerScheme.overrideRepeatCount(self.Parent.NSweepsPerRun);
                %end
            end
        end  % function
        
%         function syncIntervalAndRepeatCountListeners_(self)
%             % Delete the listeners on the old acq trigger source props
%             delete(self.TriggerSchemeIntervalAndRepeatCountListeners_);
%             self.TriggerSchemeIntervalAndRepeatCountListeners_=event.listener.empty();
%             
%             % Set up new listeners
%             if self.Parent.IsSweepBased ,
%                 if self.AcquisitionTriggerScheme.IsInternal ,
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.AcquisitionTriggerScheme.Source.addlistener('Interval', 'PostSet', ...
%                                                                          @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.AcquisitionTriggerScheme.Source.addlistener('RepeatCount', 'PostSet', ...
%                                                                          @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                 end
%             elseif self.Parent.IsContinuous ,
%                 if self.ContinuousModeTriggerScheme.IsInternal ,
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.ContinuousModeTriggerScheme.Source.addlistener('Interval', 'PostSet', ...
%                                                                             @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                     self.TriggerSchemeIntervalAndRepeatCountListeners_(end+1) = ...
%                         self.ContinuousModeTriggerScheme.Source.addlistener('RepeatCount', 'PostSet', ...
%                                                                             @(src,evt)(self.syncTriggerSourcesFromTriggeringState_()));
%                 end
%             end            
%         end  % function
    end  % protected methods block

    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = struct();
        mdlHeaderExcludeProps = {};
    end  % function
    
    methods
        function poll(self,timeSinceSweepStart)
%             % Call the task to do the real work
%             self.AcquisitionTriggerScheme.poll(timeSinceSweepStart);
%             self.StimulationTriggerScheme.poll(timeSinceSweepStart);
        end
    end    
end
