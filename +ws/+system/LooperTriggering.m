classdef LooperTriggering < ws.system.TriggeringSubsystem 
    % The triggering subsystem for the refiller process.  Doesn't need to
    % do anything except store the current triggering settings.
    
    methods
        function self = LooperTriggering(parent)
            self@ws.system.TriggeringSubsystem(parent);
        end  % function        
        
%         function acquireHardwareResources(self)
%             self.setupInternalTriggers();
%         end
        
%         function releaseHardwareResources(self)
%             %self.teardownInternalTriggers_();
%         end
        
%         function delete(self)
% %             try
% %                 self.releaseHardwareResources();
% %             catch me %#ok<NASGU>
% %                 % Can't throw in the delete() function
% %             end                
%         end  % function
                        
        function debug(self) %#ok<MANU>
            % This is to make it easy to examine the internals of the
            % object
            keyboard
        end  % function
    end  % methods block
    
%     methods        
%         function startAllTriggerTasks(self)
%             % This gets called once per sweep, to start() all the relevant
%             % counter trigger tasks.
%             
%             % Start the acq & stim trigger tasks
%             self.startAllDistinctTriggerTasks_();                
%         end  % function
%         
%         function startAllDistinctTriggerTasks_(self)
%             fprintf('LooperTriggering::startAllDistinctTriggerTasks_()\n');
% %             triggerSchemes = self.getUniqueInternalTriggersInOrderForStarting_();
% %             for idx = 1:numel(triggerSchemes) ,
% %                 thisTriggerScheme=triggerSchemes{idx};
% %                 if thisTriggerScheme==self.StimulationTriggerScheme ,
% %                     %fprintf('About to set self.IsStimulationCounterTriggerTaskRunning=true in location 3\n');
% %                     self.IsStimulationCounterTriggerTaskRunning=true;
% %                 end                    
% %                 thisTriggerScheme.start();
% %             end        
%             acquisitionTriggerScheme = self.AcquisitionTriggerScheme ;
%             stimulationTriggerScheme = self.StimulationTriggerScheme ;
%             if isa(acquisitionTriggerScheme,'ws.CounterTrigger') ,
%                 % There's an internal acq trigger scheme
%                 self.AcquisitionCounterTask_.start() ;
%                 if isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
%                     % There's an internal stim trigger scheme
%                     if stimulationTriggerScheme==acquisitionTriggerScheme ,
%                         % acq and stim share a trigger, so no need to do
%                         % anything else
%                     else
%                         self.StimulationCounterTask_.start() ;
%                     end
%                 else
%                     % stim trigger scheme is external, so nothing to do
%                 end                        
%             else
%                 % acq trigger scheme is external
%                 if isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
%                     self.StimulationCounterTask_.start() ;
%                 else
%                     % both acq & stim trigger schemes are external, so nothing to do
%                 end                                                        
%             end            
%         end  % function
%         
%         function startingRun(self) %#ok<MANU>
%         end  % function
%         
%         function startingSweep(self)
%             self.setupCounterTriggers_();
%         end  % function
% 
%         function completingSweep(self)
%             self.teardownInternalTriggers_();            
%         end  % function
%         
%         function stoppingSweep(self)
%             self.teardownInternalTriggers_();
%         end  % function
%         
%         function abortingSweep(self)
%             self.teardownInternalTriggers_();
%         end  % function
%         
%         function completingRun(self)
%             self.teardownInternalTriggers_();
%         end  % function
%         
%         function stoppingRun(self)
%             self.teardownInternalTriggers_();
%         end  % function
% 
%         function abortingRun(self)
%             self.teardownInternalTriggers_();
%         end  % function
%         
%         
% %         function triggerSourceDone(self,triggerSource)
% %             % Called "from below" when the counter trigger task finishes
% %             %fprintf('Triggering::triggerSourceDone()\n');
% %             if self.StimulationTriggerScheme.IsInternal ,
% %                 if triggerSource==self.StimulationTriggerScheme.Target ,
% %                     self.IsStimulationCounterTriggerTaskRunning=false;
% %                     self.Parent.internalStimulationCounterTriggerTaskComplete();
% %                 end
% %             end            
% %         end  % function 
%     end  % methods block
% 
%     methods (Access = protected)
%         function setupCounterTriggers_(self)        
%             acquisitionTriggerScheme = self.AcquisitionTriggerScheme ;
%             stimulationTriggerScheme = self.StimulationTriggerScheme ;
%             if isa(acquisitionTriggerScheme,'ws.CounterTrigger') ,
%                 % There's an internal acq trigger scheme
%                 self.teardownAcquisitionCounterTask_() ;
%                 self.AcquisitionCounterTask_ = self.createCounterTask_(acquisitionTriggerScheme) ;
%                 if isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
%                     % There's an internal stim trigger scheme
%                     if stimulationTriggerScheme==acquisitionTriggerScheme ,
%                         % acq and stim share a trigger, so no need to do
%                         % anything else
%                     else
%                         self.teardownStimulationCounterTask_() ;
%                         self.StimulationCounterTask_ = self.createCounterTask_(stimulationTriggerScheme) ;
%                     end
%                 else
%                     % stim trigger scheme is external, so nothing to do
%                 end                        
%             else
%                 % acq trigger scheme is external
%                 if isa(stimulationTriggerScheme,'ws.CounterTrigger') ,
%                     self.teardownStimulationCounterTask_() ;
%                     self.StimulationCounterTask_ = self.createCounterTask_(stimulationTriggerScheme) ;
%                 else
%                     % stim trigger scheme is external, so nothing to do
%                 end                                                        
%             end
% %             
% %             triggerSchemes = self.getUniqueInternalTriggersInOrderForStarting_();
% %             for idx = 1:numel(triggerSchemes) ,
% %                 thisTriggerScheme=triggerSchemes{idx};
% %                 thisTriggerScheme.setup();
% % %                 % Each trigger output is generated by a nidaqmx counter
% % %                 % task.  These tasks can themselves be configured to start
% % %                 % when they receive a trigger.  Here, we set the non-acq
% % %                 % trigger outputs to start when they receive a trigger edge on the
% % %                 % same PFI line that triggers the acquisition task.
% % %                 if thisTriggerScheme.Target ~= self.AcquisitionTriggerScheme.Target ,
% % %                     thisTriggerScheme.configureStartTrigger(self.AcquisitionTriggerScheme.PFIID, self.AcquisitionTriggerScheme.Edge);
% % %                 end                
% %                 thisTriggerScheme.configureStartTrigger(self.SweepTriggerPFIID_, self.SweepTriggerEdge_);                                
% %             end  % function            
%         end  % function
%         
%         function task = createCounterTask_(self,triggerSource)
%             % Create the counter task
%             counterID = triggerSource.CounterID ;
%             taskName = sprintf('Wavesurfer Counter Trigger Task %d',triggerSource.CounterID) ;
%             task = ...
%                 ws.ni.CounterTriggerTask(triggerSource, ...
%                                                triggerSource.DeviceName, ...
%                                                counterID, ...
%                                                taskName);
%             
%             % Set freq, repeat count                               
%             interval=triggerSource.Interval;
%             task.RepeatFrequency = 1/interval;
%             repeatCount=triggerSource.RepeatCount;
%             task.RepeatCount = repeatCount;
%             
%             % If using a non-default PFI, set that
%             pfiID = triggerSource.PFIID ;
%             if pfiID ~= counterID + 12 ,
%                 task.exportSignal(sprintf('PFI%d', pfiID));
%             end
%             
%             % TODO: Need to set the edge polarity!!!
%             
%             % Set it up to trigger off the master trigger
%             task.configureStartTrigger(self.SweepTriggerPFIID_, self.SweepTriggerEdge_);
%         end
%         
% %         function configureStartTrigger(self, pfiID, edge)
% %             self.CounterTask_.configureStartTrigger(pfiID, edge);
% %         end
%         
%         function teardownAcquisitionCounterTask_(self)
%             if ~isempty(self.AcquisitionCounterTask_) ,
%                 try
%                     self.AcquisitionCounterTask_.stop();
%                 catch me  %#ok<NASGU>
%                     % if there's a problem, can't really do much about
%                     % it...
%                 end
%             end
%             self.AcquisitionCounterTask_ = [];
%         end
%     
%         function teardownStimulationCounterTask_(self)
%             if ~isempty(self.StimulationCounterTask_) ,
%                 try
%                     self.StimulationCounterTask_.stop();
%                 catch me  %#ok<NASGU>
%                     % if there's a problem, can't really do much about
%                     % it...
%                 end
%             end
%             self.StimulationCounterTask_ = [];
%         end
%         
%     end  % protected methods block
% 
%     methods (Access = protected)
%         % Allows access to protected and protected variables from ws.mixin.Coding.
%         function out = getPropertyValue_(self, name)
%             out = self.(name);
%         end  % function
%         
%         % Allows access to protected and protected variables from ws.mixin.Coding.
%         function setPropertyValue_(self, name, value)
%             self.(name) = value;
%         end  % function
%     end  % protected methods block
%     
%     methods (Access = protected)
% %         function result = getUniqueInternalTriggersInOrderForStarting_(self)
% %             % Just what it says on the tin.  For starting, want the acq
% %             % trigger last so that the stim trigger can trigger off it if
% %             % they're using the same source.  Result is a cell array.
% %             rawTriggerSchemes = {self.StimulationTriggerScheme self.AcquisitionTriggerScheme} ;
% %             isSchemeEmpty=cellfun(@(scheme)(isempty(scheme)),rawTriggerSchemes);
% %             triggerSchemes=rawTriggerSchemes(~isSchemeEmpty);
% %             %self.StimulationTriggerScheme.IsInternal
% %             %self.AcquisitionTriggerScheme.IsInternal            
% %             isInternal=cellfun(@(scheme)(scheme.IsInternal),triggerSchemes);
% %             internalTriggerSchemes=triggerSchemes(isInternal);  % cell array
% % 
% %             % If more than one internal trigger, need to check whether
% %             % their sources are identical.  If so, only want to return one,
% %             % so we don't start an internal trigger twice.
% %             if length(internalTriggerSchemes)>1 ,
% %                 if self.StimulationTriggerScheme == self.AcquisitionTriggerScheme ,
% %                     % We pick the acq one, even though it shouldn't matter 
% %                     result=internalTriggerSchemes(2);  % singleton cell array
% %                 else
% %                     result=internalTriggerSchemes;
% %                 end
% %             else
% %                 result=internalTriggerSchemes;
% %             end
% %         end  % function
%         
%         function teardownInternalTriggers_(self)
% %             triggerSchemes = self.getUniqueInternalTriggersInOrderForStarting_();
% %             for idx = 1:numel(triggerSchemes)
% %                 triggerSchemes{idx}.teardown();
% %             end            
%             self.teardownAcquisitionCounterTask_() ;
%             self.teardownStimulationCounterTask_() ;            
%         end  % function
%     end  % protected methods block
%             
% % No need to poll the trigger tasks in current regime    
% %     methods
% %         function poll(self,timeSinceSweepStart)
% %             % Call the task to do the real work
% %             self.AcquisitionTriggerScheme.poll(timeSinceSweepStart);
% %             self.StimulationTriggerScheme.poll(timeSinceSweepStart);
% %         end
% %     end    
end  % classdef
