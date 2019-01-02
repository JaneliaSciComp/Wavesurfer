classdef TestPulser < ws.Model 
    properties  (Access=protected)  % need to see if some of these things should be transient
        ElectrodeIndex_  % index into the array of *all* electrodes (or empty)
        PulseDuration_  % the duration of the pulse, in s.  The sweep duration is twice this.
        DoSubtractBaseline_
        YLimits_
        IsAutoY_  % if true, the y limits are synced to the monitor signal currently in view
        IsAutoYRepeating_
            % If IsAutoY_ is true:
            %     If IsAutoYRepeating_ is true , we sync the y limits to the monitor signal currently in
            %     view every N test pulses.  if false, the syncing is only done once,
            %     after one of the early test pulses
            % If IsAutoY_ is false:
            %     Has no effect.
        DesiredRateOfAutoYing_ = 10  % Hz, for now this never changes
            % The desired rate of syncing the Y to the data
    end
    
    properties  (Access=protected, Transient=true)
        IsRunning_
        UpdateRate_
        NSweepsCompletedThisRun_
        InputTask_
        OutputTask_
        TimerValue_
        LastToc_
        AmplitudePerElectrodeCached_  % cached double version of AmplitudeAsDoublePerElectrode, for speed during sweeps
        IsCCPerElectrodeCached_  
        IsVCPerElectrodeCached_  
        MonitorChannelInverseScalePerElectrodeCached_
        MonitorCached_  % a cache of the monitor signal for the current electrode
        NScansInSweepCached_
        NElectrodesCached_
        I0BaseCached_
        IfBaseCached_
        I0PulseCached_
        IfPulseCached_
        GainPerElectrode_
        GainOrResistancePerElectrode_
        MonitorPerElectrode_
        NSweepsPerAutoY_  % if IsAutoY_ and IsAutoYRepeating_, we update the y limits every this many sweeps (if we can)
        NSweepsCompletedAsOfLastYLimitsUpdate_
        GainOrResistanceUnitsPerElectrodeCached_
        SamplingRateCached_
    end    
    
    methods
        function self = TestPulser()            
            %self@ws.Model() ;
            % ElectrodeIndex_ defaults to empty, therefore there is no test pulse
            % electrode as far as we're concerned
            self.PulseDuration_ = 10e-3 ;  % s
            self.DoSubtractBaseline_=true;
            self.IsAutoY_=true;
            self.IsAutoYRepeating_=false;
            self.YLimits_=[-10 +10];
            self.IsRunning_=false;
            self.UpdateRate_=nan;
            self.MonitorPerElectrode_ = [] ;
        end  % method
        
        function delete(self)  %#ok<INUSD>
            %self.Parent_=[];  % not necessary, but harmless
        end  % method
        
        function didSetAnalogChannelUnitsOrScales(self)
            self.clearExistingSweepIfPresent_();
            %self.broadcast('Update');            
        end
           
        function result = getElectrodeIndex(self)
            result = self.ElectrodeIndex_ ;
        end

        function setElectrodeIndex(self, newValue)
            oldValue = self.ElectrodeIndex_ ;
            self.ElectrodeIndex_ = newValue ;
            if ~isequal(newValue, oldValue) ,
                self.clearExistingSweepIfPresent_() ;
            end
            %self.setCurrentTPElectrodeToFirstTPElectrodeIfInvalidOrEmpty_(electrodeCount) ;
        end
        
        function value=getPulseDuration_(self)  % s
            %value=1e-3*str2double(self.PulseDurationInMsAsString_);  % ms->s
            value = self.PulseDuration_ ;
        end
        
        function setPulseDuration(self, newValue)  % the duration of the pulse, in seconds.  The sweep duration is twice this.
            if isscalar(newValue) && isreal(newValue) && isfinite(newValue) ,
                self.PulseDuration_ = max(5e-3, min(double(newValue), 500e-3)) ;
                self.clearExistingSweepIfPresent_() ;
            end
            %self.broadcast('Update');
        end

        function commands = getCommandPerElectrode(self, fs, amplitudePerElectrode)  
            % Command signal for each test pulser electrode, each in units given by the ChannelUnits property 
            % of the Stimulation object
            %t = self.Time ;  % col vector
            t = self.getTime_(fs) ;  % col vector
            delay = self.PulseDuration_/2 ;
            %amplitudePerElectrode = self.AmplitudePerElectrode ;  % row vector
            unscaledCommand = (delay<=t)&(t<delay+self.PulseDuration_) ;  % col vector
            commands = bsxfun(@times, amplitudePerElectrode, unscaledCommand) ;
        end  
        
        function commandsInVolts = getCommandInVoltsPerElectrode(self, fs, amplitudePerElectrode, commandChannelScalePerTestPulseElectrode)  
            % the command signals, in volts to be sent out the AO channels
            %commands=self.CommandPerElectrode;   % (nScans x nCommandChannels)
            commands = self.getCommandPerElectrode(fs, amplitudePerElectrode) ;  % (nScans x nCommandChannels)
            %commandChannelScales=self.CommandChannelScalePerElectrode;  % 1 x nCommandChannels
            inverseChannelScales=1./commandChannelScalePerTestPulseElectrode;
            % zero any channels that have infinite (or nan) scale factor
            sanitizedInverseChannelScales=ws.fif(isfinite(inverseChannelScales), inverseChannelScales, zeros(size(inverseChannelScales)));
            commandsInVolts=bsxfun(@times,commands,sanitizedInverseChannelScales);
        end                                                        

        function value=getDoSubtractBaseline_(self)
            value=self.DoSubtractBaseline_;
        end
        
        function setDoSubtractBaseline(self, newValue)
            if islogical(newValue) ,
                self.DoSubtractBaseline_ = newValue ;
                self.clearExistingSweepIfPresent_();
            end
            %self.broadcast('Update');
        end
        
        function value=getIsAutoY_(self)
            value=self.IsAutoY_;
        end
        
        function setIsAutoY_(self,newValue)
            if islogical(newValue) ,
                self.IsAutoY_=newValue;
                if self.IsAutoY_ ,                
                    yLimits=self.automaticYLimits();
                    if ~isempty(yLimits) ,                    
                        self.YLimits_=yLimits;
                    end
                end
            end
            %self.broadcast('Update');
        end
        
        function value=getIsAutoYRepeating_(self)
            value=self.IsAutoYRepeating_;
        end
        
        function setIsAutoYRepeating_(self, newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.IsAutoYRepeating_=newValue;
            end
            %self.broadcast('Update');
        end
              
        function value = getTime_(self, fs)  % s
            dt = 1/fs ;  % s
            nScansInSweep = self.getNScansInSweep_(fs) ;
            value = dt*(0:(nScansInSweep-1))' ;  % s
        end
        
        function value = getNScansInSweep_(self, fs)
            dt = 1/fs ;  % s
            sweepDuration = 2*self.PulseDuration_ ;
            value = round(sweepDuration/dt) ;
        end
        
        function value=getIsRunning_(self)
            value=self.IsRunning_;
        end

        function result = getGainOrResistanceUnitsPerTestPulseElectrodeCached_(self)
            result = self.GainOrResistanceUnitsPerElectrodeCached_ ;
        end        

        function result = getGainOrResistancePerElectrode(self)
            result = self.GainOrResistancePerElectrode_ ;
        end
        
        function value = getUpdateRate_(self)
            value = self.UpdateRate_ ;
        end
        
        function yLimits = automaticYLimits(self)
            % Trys to determine the automatic y limits from the monitor
            % signal.  If succful, returns them.  If unsuccessful, returns empty.
            monitor = self.MonitorCached_ ;
            if isempty(monitor) ,
                yLimits = [] ;
            else
                monitorMax=max(monitor);
                monitorMin=min(monitor);
                if ~isempty(monitorMax) && ~isempty(monitorMin) && isfinite(monitorMin) && isfinite(monitorMax) ,
                    monitorCenter=(monitorMin+monitorMax)/2;
                    monitorRadius=(monitorMax-monitorMin)/2;
                    if monitorRadius==0 ,
                        yLo=monitorCenter-10;
                        yHi=monitorCenter+10;
                    else
                        yLo=monitorCenter-1.2*monitorRadius;
                        yHi=monitorCenter+1.2*monitorRadius;
                    end
                    yLimits=[yLo yHi];
                else
                    yLimits=[];
                end            
            end
        end  % function

        function setYLimits(self, newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2),
                self.YLimits_=newValue;
            end
            %self.broadcast('Update');
        end
        
        function result = getYLimits_(self)
            result = self.YLimits_ ;
        end

        function addingElectrode(self, newElectrodeIndex, electrodeCountAfter)  %#ok<INUSL>
            % Called by the parent Ephys when an electrode is added.
            %self.clearExistingSweepIfPresent_() ;
            %if isempty(self.ElectrodeIndex_) && isElectrodeMarkedForTestPulseAfter,
            %    self.ElectrodeIndex_ = electrodeIndex ;
            %end
            if isempty(self.ElectrodeIndex_) && electrodeCountAfter>=1 ,
                self.setElectrodeIndex(1) ;
            end
            %self.broadcast('Update') ;
        end

        function electrodesRemoved(self, wasRemoved, electrodeCountAfter)
            % Called by the parent Ephys when one or more electrodes are
            % removed.
            electrodeIndexBefore = self.ElectrodeIndex_ ;
            
            if isempty(electrodeIndexBefore) ,
                % Not much to do in this case
            else                
                % Check if the TP trode was removed
                wasTPElectrodeRemoved = wasRemoved(electrodeIndexBefore) ;
                if wasTPElectrodeRemoved ,
                    % TP trode *was* removed
                    if electrodeCountAfter>=1 ,
                        % If there's any other electrodes, set the TP trode to the first one
                        % Can't use setElectrodeIndex() b/c want to force the clearing of the
                        % existing sweep
                        self.setElectrodeIndex(1) ;
                        if electrodeIndexBefore==1 ,
                            % setElectrodeIndex() won't do this if the new index is the same, even though
                            % it's a different trode now.
                            self.clearExistingSweepIfPresent_() ;
                        end
                    else
                        % If no electrodes left, there can be no TP trode
                        self.setElectrodeIndex([]) ;  % this will clear, b/c electrodeIndexBefore is nonempty
                    end
                else                    
                    % TP trode was *not* removed
                    % Correct the electrode index
                    self.ElectrodeIndex_ = ws.correctIndexAfterRemoval(electrodeIndexBefore, wasRemoved) ;
                end
            end
            
            %self.broadcast('Update') ;
        end  % function
        
        function prepareForStart(self, ...
                                 amplitudePerTestPulseElectrode, ...
                                 fs, ...
                                 gainOrResistanceUnitsPerTestPulseElectrode, ...
                                 isVCPerTestPulseElectrode, ...
                                 isCCPerTestPulseElectrode, ...
                                 commandTerminalIDPerTestPulseElectrode, ...
                                 monitorTerminalIDPerTestPulseElectrode, ...
                                 commandChannelScalePerTestPulseElectrode, ...
                                 monitorChannelScalePerTestPulseElectrode, ...
                                 deviceName, ...
                                 primaryDeviceName, ...
                                 isPrimaryDeviceAPXIDevice, ...
                                 wsModel)
            % Get the stimulus
            commandsInVolts = self.getCommandInVoltsPerElectrode(fs, amplitudePerTestPulseElectrode, commandChannelScalePerTestPulseElectrode) ;
            nScans=size(commandsInVolts,1);
            nElectrodes=size(commandsInVolts,2);

            % Set up the input task
            % fprintf('About to create the input task...\n');
            self.InputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Input');
            for i=1:nElectrodes ,
                self.InputTask_.createAIVoltageChan(deviceName, monitorTerminalIDPerTestPulseElectrode(i));  % defaults to differential
            end
            [referenceClockSource, referenceClockRate] = ...
                ws.getReferenceClockSourceAndRate(deviceName, primaryDeviceName, isPrimaryDeviceAPXIDevice) ;
            set(self.InputTask_, 'refClkSrc', referenceClockSource) ;
            set(self.InputTask_, 'refClkRate', referenceClockRate) ;            
            %deviceName = self.Parent.Parent.DeviceName ;
            clockString=sprintf('/%s/ao/SampleClock',deviceName);  % device name is something like 'Dev3'
            self.InputTask_.cfgSampClkTiming(fs,'DAQmx_Val_ContSamps',[],clockString);
              % set the sampling rate, and use the AO sample clock to keep
              % acquisiton synced with analog output
            self.InputTask_.cfgInputBuffer(10*nScans);

            % Set up the output task
            % fprintf('About to create the output task...\n');
            self.OutputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Output');
            for i=1:nElectrodes ,
                self.OutputTask_.createAOVoltageChan(deviceName, commandTerminalIDPerTestPulseElectrode(i));
            end
            set(self.OutputTask_, 'refClkSrc', referenceClockSource) ;
            set(self.OutputTask_, 'refClkRate', referenceClockRate) ;            
            self.OutputTask_.cfgSampClkTiming(fs,'DAQmx_Val_ContSamps',nScans);

            % Limit the stimulus to the allowable range
            limitedCommandsInVolts=max(-10,min(commandsInVolts,+10));

            % Write the command to the output task                
            self.OutputTask_.writeAnalogData(limitedCommandsInVolts);

            % Set up the input task callback
            %nSamplesPerSweep=nScans*nElectrodes;
            self.InputTask_.everyNSamples = nScans ;
            self.InputTask_.everyNSamplesEventCallbacks = @(varargin)(wsModel.completingTestPulserSweep()) ;

            % Cache some things for speed during sweeps
            self.IsVCPerElectrodeCached_ = isVCPerTestPulseElectrode ;
            self.IsCCPerElectrodeCached_ = isCCPerTestPulseElectrode;
            self.MonitorChannelInverseScalePerElectrodeCached_ = 1./monitorChannelScalePerTestPulseElectrode ;
            self.AmplitudePerElectrodeCached_ = amplitudePerTestPulseElectrode ;
            %self.IndexOfElectrodeWithinTPElectrodesCached_ = indexOfTestPulseElectrodeWithinTestPulseElectrodes ;
            self.NScansInSweepCached_ = self.getNScansInSweep_(fs) ;
            self.NElectrodesCached_ = double(~isempty(self.ElectrodeIndex_)) ;
            self.GainOrResistanceUnitsPerElectrodeCached_ = gainOrResistanceUnitsPerTestPulseElectrode ;
            self.SamplingRateCached_ = fs ;

            % Compute some indices and cache them, again for speed during
            % sweeps
            sweepDuration = 2 * self.PulseDuration_ ;  % s
            t0Base=0; % s
            tfBase=1/8*sweepDuration; % s
            t0Pulse=5/8*sweepDuration; % s
            tfPulse=6/8*sweepDuration; % s
            %dt=self.Dt;
            dt = 1/fs;  % s
            self.I0BaseCached_ = floor(t0Base/dt)+1;
            self.IfBaseCached_ = floor(tfBase/dt);
            self.I0PulseCached_ = floor(t0Pulse/dt)+1;
            self.IfPulseCached_ = floor(tfPulse/dt);            

            % Set the where-the-rubber-meets-the-road auto-Y parameters, given the user-supplied parameters
            if self.IsAutoY_ ,
                if self.IsAutoYRepeating_ ,
                    % repeating auto y
                    self.NSweepsCompletedAsOfLastYLimitsUpdate_ = -inf ;
                    self.NSweepsPerAutoY_ =  min(1,round(1/(sweepDuration * self.DesiredRateOfAutoYing_))) ;
                else
                    % Auto Y only at start
                    self.NSweepsCompletedAsOfLastYLimitsUpdate_ = -inf ;
                    self.NSweepsPerAutoY_ = inf ;
                        % this ends up working b/c inf>=inf in IEEE
                        % floating-point 
                end
            else
                % No auto Y
                self.NSweepsCompletedAsOfLastYLimitsUpdate_ = inf ;  % this will make it so that y limits are never updated
                self.NSweepsPerAutoY_ = 1 ;  % this doesn't matter, b/c of the line above, so just set to unity
            end

            % Finish up the prep
            self.NSweepsCompletedThisRun_=0;
            self.IsRunning_=true;
        end  % function
        
        function start_(self)
            % Set up timing
            self.TimerValue_=tic();
            self.LastToc_=toc(self.TimerValue_);
            
            % actually start the data acq tasks
            self.InputTask_.start();  % won't actually start until output starts b/c see above
            self.OutputTask_.start();
        end
        
        function stop_(self)
            % This is what gets called when the user presses the 'Stop' button,
            % for instance.
            %fprintf('Just entered stop()...\n');            
            % Takes some time to stop...
            %self.changeReadiness(-1);
            %self.IsReady_ = false ;
            %self.broadcast('UpdateReadiness');

            %if self.IsStopping_ ,
            %    fprintf('Stopping while already stopping...\n');
            %    dbstack
            %else
            %    self.IsStopping_=true;
            %end
            if ~isempty(self.OutputTask_) ,
                self.OutputTask_.stop();
            end
            if ~isempty(self.InputTask_) ,            
                self.InputTask_.stop();
            end

            %
            % make sure the output is set to the non-pulsed state
            % (Is there a better way to do this?)
            %
            nScans = 2 ;
            self.OutputTask_.cfgSampClkTiming(self.SamplingRateCached_,'DAQmx_Val_ContSamps',nScans);
            %commandsInVolts=zeros(self.NScansInSweep,self.NElectrodes);
            commandsInVolts=zeros(nScans,self.NElectrodesCached_);
            self.OutputTask_.writeAnalogData(commandsInVolts);
            self.OutputTask_.start();
            % pause for 10 ms without relinquishing control
%             timerVal=tic();
%             while (toc(timerVal)<0.010)
%                 x=1+1; %#ok<NASGU>
%             end            
            ws.restlessSleep(0.010);  % pause for 10 ms
            self.OutputTask_.stop();
            % % Maybe try this: java.lang.Thread.sleep(10);

            % Continue with stopping stuff
            % fprintf('About to delete the tasks...\n');
            %self
            delete(self.InputTask_);  % Have to explicitly delete b/c it's a DABS task
            delete(self.OutputTask_);  % Have to explicitly delete b/c it's a DABS task
            self.InputTask_=[];
            self.OutputTask_=[];
            % maybe need to do more here...
            self.IsRunning_=false;

%                 % Notify the rest of Wavesurfer
%                 ephys=self.Parent;
%                 wavesurferModel=[];
%                 if ~isempty(ephys) ,
%                     wavesurferModel=ephys.Parent;
%                 end                
%                 if ~isempty(wavesurferModel) ,
%                     wavesurferModel.didPerformTestPulse();
%                 end

            % Takes some time to stop...
            %self.changeReadiness(+1);
            %self.IsReady_ = true ;
            %self.broadcast('Update');
        end  % function
        
        function abort_(self)
            % This is called when a problem arises during test pulsing, and we
            % want to try very hard to get back to a known, sane, state.

            % % And now we are once again ready to service method calls...
            % self.changeReadiness(-1);

            % Try to gracefully wind down the output task
            if isempty(self.OutputTask_) ,
                % nothing to do here
            else
                if isvalid(self.OutputTask_) ,
                    try
                        self.OutputTask_.stop();
                        delete(self.OutputTask_);  % it's a DABS task, so have to manually delete
                          % this delete() can throw, if, e.g. the daq board has
                          % been turned off.  We discard the error because we're
                          % trying to do the best we can here.
                    catch me  %#ok<NASGU>
                        % Not clear what to do here...
                        % For now, just ignore the error and forge ahead
                    end
                end
                % At this point self.OutputTask_ is no longer valid
                self.OutputTask_ = [] ;
            end
            
            % Try to gracefully wind down the input task
            if isempty(self.InputTask_) ,
                % nothing to do here
            else
                if isvalid(self.InputTask_) ,
                    try
                        self.InputTask_.stop();
                        delete(self.InputTask_);  % it's a DABS task, so have to manually delete
                          % this delete() can throw, if, e.g. the daq board has
                          % been turned off.  We discard the error because we're
                          % trying to do the best we can here.
                    catch me  %#ok<NASGU>
                        % Not clear what to do here...
                        % For now, just ignore the error and forge ahead
                    end
                end
                % At this point self.InputTask_ is no longer valid
                self.InputTask_ = [] ;
            end
            
            % Set the current run state
            self.IsRunning_=false;

%             % Notify the rest of Wavesurfer
%             ephys=self.Parent;
%             wavesurferModel=[];
%             if ~isempty(ephys) ,
%                 wavesurferModel=ephys.Parent;
%             end                
%             if ~isempty(wavesurferModel) ,
%                 wavesurferModel.didAbortTestPulse();
%             end
            
            % % And now we are once again ready to service method calls...
            % self.changeReadiness(+1);
        end  % function
        
        function completingSweep(self, varargin)
            % compute resistance
            % compute delta in monitor
            % Specify the time windows for measuring the baseline and the pulse amplitude
            rawMonitor=self.InputTask_.readAnalogData(self.NScansInSweepCached_);  % rawMonitor is in V, is NScansInSweep x NElectrodes
                % We now read exactly the number of scans we expect.  Not
                % doing this seemed to work fine on ALT's machine, but caused
                % nasty jitter issues on Minoru's rig machine.  In retrospect, kinda
                % surprising it ever worked without specifying this...
            if size(rawMonitor,1)~=self.NScansInSweepCached_ ,
                % this seems to happen occasionally, and when it does we abort the update
                return  
            end
            scaledMonitor=bsxfun(@times,rawMonitor,self.MonitorChannelInverseScalePerElectrodeCached_);
            i0Base=self.I0BaseCached_;
            ifBase=self.IfBaseCached_;
            i0Pulse=self.I0PulseCached_;
            ifPulse=self.IfPulseCached_;
            base=mean(scaledMonitor(i0Base:ifBase,:),1);
            pulse=mean(scaledMonitor(i0Pulse:ifPulse,:),1);
            monitorDelta=pulse-base;
            self.GainPerElectrode_=monitorDelta./self.AmplitudePerElectrodeCached_;
            % Compute resistance per electrode
            self.GainOrResistancePerElectrode_=self.GainPerElectrode_;
            self.GainOrResistancePerElectrode_(self.IsVCPerElectrodeCached_)= ...
                1./self.GainPerElectrode_(self.IsVCPerElectrodeCached_);
            if self.DoSubtractBaseline_ ,
                self.MonitorPerElectrode_=bsxfun(@minus,scaledMonitor,base);
            else
                self.MonitorPerElectrode_=scaledMonitor;
            end
            self.MonitorCached_=self.MonitorPerElectrode_ ;
            self.tryToSetYLimitsIfCalledFor_();
            self.NSweepsCompletedThisRun_=self.NSweepsCompletedThisRun_+1;
            
            % Update the UpdateRate_
            thisToc=toc(self.TimerValue_);
            if ~isempty(self.LastToc_) ,
                updateInterval=thisToc-self.LastToc_;  % s
                self.UpdateRate_=1/updateInterval;  % Hz
                %fprintf('Update frequency: %0.1f Hz\n',updateFrequency);
            end
            self.LastToc_=thisToc;
            
            %self.broadcast('UpdateTrace');
            %fprintf('About to exit TestPulser::completingSweep()\n');            
        end  % function
        
        function zoomIn(self)
            yLimits=self.YLimits_;
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+0.5*yRadius*[-1 +1];
            self.YLimits_ = newYLimits;
            %self.broadcast('Update');
        end  % function
        
        function zoomOut(self)
            yLimits=self.YLimits_;
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+2*yRadius*[-1 +1];
            self.YLimits_ = newYLimits ;
            %self.broadcast('Update');
        end  % function
        
        function scrollUp(self)
            yLimits=self.YLimits_;
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1];
            self.YLimits_ = newYLimits ;
            %self.broadcast('Update');
        end  % function
        
        function scrollDown(self)
            yLimits=self.YLimits_;
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1];
            self.YLimits_ = newYLimits ;
            %self.broadcast('Update');
        end  % function
                
        function didSetAcquisitionSampleRate(self, newValue)  %#ok<INUSD>
            % newValue has already been validated
            %self.setSamplingRate_(newValue) ;  % This will fire Update, etc.
            self.clearExistingSweepIfPresent_() ;        
        end       
        
%         function didSetIsInputChannelActive(self) 
%             %self.broadcast('DidSetIsInputChannelActive');
%         end
    end  % methods
        
    methods (Access=protected)                
        function clearExistingSweepIfPresent_(self)
            self.MonitorPerElectrode_ = [] ;
            self.MonitorCached_ = [] ;
            if isempty(self.ElectrodeIndex_) ,                
                self.GainPerElectrode_ = [] ;
                self.GainOrResistancePerElectrode_ = [] ;
            else
                self.GainPerElectrode_ = nan ;
                self.GainOrResistancePerElectrode_ = nan ;
            end
            self.UpdateRate_ = nan ;
        end  % function
        
        function tryToSetYLimitsIfCalledFor_(self)
            % If setting the y limits is appropriate right now, try to set them
            % Sets AreYLimitsForRunDetermined_ and YLimits_ if successful.
            if self.IsRunning_ ,
                nSweepsSinceLastUpdate = self.NSweepsCompletedThisRun_ - self.NSweepsCompletedAsOfLastYLimitsUpdate_ ;
                if nSweepsSinceLastUpdate >= self.NSweepsPerAutoY_ ,
                    yLimits=self.automaticYLimits();
                    if ~isempty(yLimits) ,
                        self.NSweepsCompletedAsOfLastYLimitsUpdate_ = self.NSweepsCompletedThisRun_ ;
                        self.YLimits_ = yLimits ;
                    end
                end
            end
        end  % function        
    end  % protected methods block
    
    methods
        function result = getMonitorPerElectrode_(self)
            result = self.MonitorPerElectrode_ ;
        end
    end
    
    % These next two methods allow access to private and protected variables from ws.Encodable. 
    methods 
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    methods
        function mimic(self, other)
            ws.mimicBang(self, other) ;
        end
        
        function synchronizeTransientStateToPersistedState_(self)
            self.clearExistingSweepIfPresent_() ;  % mainly to dimension self.GainPerElectrode_ and self.GainOrResistancePerElectrode_ properly
        end  % function                
    end    
    
end  % classdef
