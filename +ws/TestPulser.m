classdef TestPulser < ws.Model 
    properties (Dependent=true)  % do we need *so* many public properties?
        ElectrodeName
        PulseDurationInMsAsString  % the duration of the pulse, in ms.  The sweep duration is twice this.
        DoSubtractBaseline
        IsAutoY
        IsAutoYRepeating
        YLimits
        YUnits
        IsRunning
    end
    
    properties (Dependent = true, SetAccess = immutable)  % do we need *so* many public properties?
        %Dt  % s
        SweepDuration  % s
        %NScansInSweep
        %Time  % s
        ElectrodeNames
        CommandChannelNames
        MonitorChannelNames
        PulseDuration  % s
        %SamplingRate  % in Hz
        CommandUnits
        MonitorUnits
        IsCC
        IsVC
        UpdateRate
        NSweepsCompletedThisRun
        %CommandTerminalID
        %MonitorTerminalID
%         MonitorChannelScale
%         CommandChannelScale
        %AmplitudePerElectrode
        %CommandPerElectrode
        CommandChannelScalePerElectrode
        MonitorChannelScalePerElectrode
        %CommandInVoltsPerElectrode
        CommandTerminalIDPerElectrode
        MonitorTerminalIDPerElectrode
        IsCCPerElectrode
        IsVCPerElectrode
        CommandUnitsPerElectrode
        MonitorUnitsPerElectrode
        %GainOrResistanceUnitsPerElectrode
        %GainOrResistancePerElectrode
        %NElectrodes
    end
    
    properties  (Access=protected)  % need to see if some of these things should be transient
        ElectrodeName_  
        PulseDurationInMsAsString_  % the duration of the pulse, in ms.  The sweep duration is twice this.
        DoSubtractBaseline_
        %SamplingRate_  % in Hz
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
        %NElectrodes_  
          % We need to remember this in order to properly size certain arrays.
          % Generally, care must be taken to make sure this agrees with the number of
          % test pulse electrodes in the electrode manager.
    end
    
    properties  (Access=protected, Transient=true)
        %Parent_  % an Ephys object
        %Electrode_  % the current electrode, or empty if there isn't one.  We persist ElectrodeName_, not this.  
        IsRunning_
        UpdateRate_
        NSweepsCompletedThisRun_
        InputTask_
        OutputTask_
        TimerValue_
        LastToc_
        %AreYLimitsForRunDetermined_  %  whether the proper y limits for the ongoing run have been determined
        IndexOfElectrodeWithinTPElectrodesCached_
        %IsCCCached_  % true iff the electrode is in current-clamp mode, cached for speed when acquiring data
        %IsVCCached_  % true iff the electrode is in voltage-clamp mode, cached for speed when acquiring data
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
        %IsReady_
        GainOrResistanceUnitsPerElectrodeCached_
        DeviceName_
        SamplingRateCached_
    end    
    
    events
        DidSetIsInputChannelActive
        UpdateTrace
        %UpdateReadiness
    end
    
    methods
        function self = TestPulser(parent)
            % Process args
            self@ws.Model(parent);
%             validPropNames=ws.findPropertiesSuchThat(self,'SetAccess','public');
%             mandatoryPropNames=cell(1,0);
%             pvArgs = ws.filterPVArgs(varargin,validPropNames,mandatoryPropNames);
%             propNamesRaw = pvArgs(1:2:end);
%             propValsRaw = pvArgs(2:2:end);
%             nPVs=length(propValsRaw);  % Use the number of vals in case length(varargin) is odd
%             propNames=propNamesRaw(1:nPVs);
%             propVals=propValsRaw(1:nPVs);            
%             
%             % Set the properties
%             for idx = 1:nPVs
%                 self.(propNames{idx}) = propVals{idx};
%             end
            
%             ephys=[];
%             %electrodeManager=[];
%             %electrodes=cell(0,1);
% %             electrode=[];
%             if ~isempty(self.Parent_)
%                 ephys=self.Parent_;
%             end
%             if ~isempty(ephys)
%                 electrodeManager=ephys.ElectrodeManager;
%             end
%             if ~isempty(electrodeManager)
%                 electrodes=electrodeManager.TestPulseElectrodes;
%             end
%             if ~isempty(electrodes) ,
%                 electrode=electrodes{1};
%             end           
            %self.Electrode_=electrode;

            self.PulseDurationInMsAsString_='10';  % ms
            %self.Amplitude_='10';  % units determined by electrode mode, channel units
            %self.AmplitudeAsDouble_=self.Amplitude.toDouble();  % keep around in this form for speed during sweeps
            self.DoSubtractBaseline_=true;
            self.IsAutoY_=true;
            self.IsAutoYRepeating_=false;
            self.YLimits_=[-10 +10];
            
%             wsModel = ws.getSubproperty(ephys,'Parent');
%             if isempty(wsModel) ,
%                 self.SamplingRate_ = 20e3 ;  % Hz
%             else
%                 self.SamplingRate_ = wsModel.AcquisitionSampleRate ;  % Hz
%             end
            
            self.IsRunning_=false;
            self.UpdateRate_=nan;
            %self.MonitorPerElectrode_=nan(self.NScansInSweep,self.NElectrodes);
            %self.NElectrodes_ = 0 ;
            self.MonitorPerElectrode_ = [] ;
        end  % method
        
%         function setNElectrodes_(self, newValue)
%             self.NElectrodes_ = newValue ;
%             self.clearExistingSweepIfPresent_() ;
%         end
        
        function delete(self)
            self.Parent_=[];  % not necessary, but harmless
        end  % method
        
        function do(self, methodName, varargin)
            % This is intended to be the usual way of calling model
            % methods.  For instance, a call to a ws.Controller
            % controlActuated() method should generally result in a single
            % call to .do() on it's model object, and zero direct calls to
            % model methods.  This gives us a
            % good way to implement functionality that is common to all
            % model method calls, when they are called as the main "thing"
            % the user wanted to accomplish.  For instance, we start
            % warning logging near the beginning of the .do() method, and turn
            % it off near the end.  That way we don't have to do it for
            % each model method, and we only do it once per user command.            
            root = self.Parent.Parent ;
            root.startLoggingWarnings() ;
            try
                self.(methodName)(varargin{:}) ;
            catch exception
                % If there's a real exception, the warnings no longer
                % matter.  But we want to restore the model to the
                % non-logging state.
                root.stopLoggingWarnings() ;  % discard the result, which might contain warnings
                rethrow(exception) ;
            end
            warningExceptionMaybe = root.stopLoggingWarnings() ;
            if ~isempty(warningExceptionMaybe) ,
                warningException = warningExceptionMaybe{1} ;
                throw(warningException) ;
            end
        end
        
%         % This is designed to be called by an EventBroadcaster if a
%         % subscribed-to event happens
%         function eventHappened(self,broadcaster,eventName,propertyName,source,event)   %#ok<INUSD,INUSL>
%             if isequal(eventName,'DidSetAnalogChannelUnitsOrScales')
%                 self.clearExistingSweepIfPresent_();
%                 self.broadcast('Update');
%             end
%         end
        
        function self=didSetAnalogChannelUnitsOrScales(self)
            self.clearExistingSweepIfPresent_();
            self.broadcast('Update');            
        end
           
        function didChangeNumberOfInputChannels(self)
            self.broadcast('Update');
        end
        
        function didChangeNumberOfOutputChannels(self)
            self.broadcast('Update');
        end
        
        function value=get.ElectrodeName(self)
            value=self.ElectrodeName_;
        end

        function set.ElectrodeName(self,newValue)
            if isempty(newValue) ,
                self.ElectrodeName_ = '';
                %self.Electrode_ = [];                
            else
                % Check that the newValue is an available electrode, unless we
                % can't get a list of electrodes.
                ephys=self.Parent_;
                if isempty(ephys)
                    electrodeManager=[];
                    electrodeNames={newValue};
                else
                    electrodeManager=ephys.ElectrodeManager;
                    if isempty(electrodeManager) ,
                        electrodeNames={newValue};
                    else    
                        electrodeNames=electrodeManager.TestPulseElectrodeNames;
                    end
                end
                newValueFiltered=electrodeNames(strcmp(newValue,electrodeNames));
                if ~isempty(newValueFiltered) ,
                    electrodeName=newValueFiltered{1};  % if multiple matches, choose the first (hopefully rare)
                    if isempty(electrodeManager)
                        self.ElectrodeName_ = electrodeName;  % this is a fall-back
                        %self.Electrode_ = [];
                    else
                        %electrode=electrodeManager.getElectrodeByName(electrodeName);
                        self.ElectrodeName_ = electrodeName;
                        %self.Electrode_ = electrode;
                    end
                end
            end
            self.broadcast('Update');
        end
        
%         function result=get.Electrodes(self)
%             ephys=self.Parent_;
%             electrodeManager=ephys.ElectrodeManager;
%             result=electrodeManager.TestPulseElectrodes;
%         end
        
%         function value=get.CommandChannelName(self)
%             electrode=self.Electrode_;
%             if isempty(electrode) ,
%                 value='';
%             else
%                 value=electrode.CommandChannelName;
%             end
%         end
        
%         function set.CommandChannelName(self,newValue)
%             channelNames=self.Parent_.Stimulation.ChannelNames;
%             newValueFiltered=channelNames(strcmp(newValue,channelNames));
%             if ~isempty(newValueFiltered) ,
%                 self.CommandChannelName_=newValueFiltered;
%                 self.clearExistingSweepIfPresent_();
%             end
%             self.broadcast('Update');
%         end
        
%         function value=get.MonitorChannelName(self)
%             electrode=self.Electrode_;
%             if isempty(electrode) ,
%                 value='';
%             else
%                 value=electrode.MonitorChannelName;
%             end
%         end
        
%         function set.MonitorChannelName(self,newValue)
%             channelNames=self.Parent_.Acquisition.ChannelNames;
%             newValueFiltered=channelNames(strcmp(newValue,channelNames));
%             if ~isempty(newValueFiltered) ,
%                 self.MonitorChannelName_=newValueFiltered;
%                 self.clearExistingSweepIfPresent_();
%             end
%             self.broadcast('Update');
%         end        
        
        function value=get.NSweepsCompletedThisRun(self)
            value=self.NSweepsCompletedThisRun_;
        end
        
%         function result=get.NElectrodes(self)
%             % Get the amplitudes of the test pulse for all the
%             % marked-for-test-pulsing electrodes, as a double array.            
%             ephys=self.Parent_;
%             if isempty(ephys) ,
%                 result=0;
%             else
%                 electrodeManager=ephys.ElectrodeManager;
%                 if isempty(electrodeManager) ,
%                     result=0;
%                 else
%                     result=length(electrodeManager.TestPulseElectrodes);
%                 end
%             end
%         end
        
%         function result=get.AmplitudePerElectrode(self)
%             % Get the amplitudes of the test pulse for all the
%             % marked-for-test-pulsing electrodes, as a double array.            
%             ephys=self.Parent_;
%             electrodeManager=ephys.ElectrodeManager;
%             testPulseElectrodes=electrodeManager.TestPulseElectrodes;
%             %resultAsCellArray={testPulseElectrodes.TestPulseAmplitude};
%             result=cellfun(@(electrode)(electrode.TestPulseAmplitude), ...
%                            testPulseElectrodes);
%         end
        
%         function value=get.Amplitude(self)
%             if isempty(self.Electrode_)
%                 %value=ws.DoubleString('');
%                 value=nan;
%             else
%                 value=self.Electrode_.TestPulseAmplitude;
%             end
%         end
        
%         function set.Amplitude(self, newValue)  % in units of the electrode command channel
%             if ~isempty(self.Electrode_) ,
%                 if ws.isString(newValue) ,
%                     newValueAsDouble = str2double(newValue) ;
%                 elseif isnumeric(newValue) && isscalar(newValue) ,
%                     newValueAsDouble = double(newValue) ;
%                 else
%                     newValueAsDouble = nan ;  % isfinite(nan) is false
%                 end
%                 if isfinite(newValueAsDouble) ,
%                     self.Electrode_.TestPulseAmplitude = newValueAsDouble ;
%                     %self.AmplitudeAsDouble_=newValue;
%                     self.clearExistingSweepIfPresent_() ;
%                 else
%                     self.broadcast('Update') ;
%                     error('ws:invalidPropertyValue', ...
%                           'Amplitude must be a finite scalar');
%                 end
%             end                
%             self.broadcast('Update') ;
%         end
        
        function value=get.PulseDuration(self)  % s
            value=1e-3*str2double(self.PulseDurationInMsAsString_);  % ms->s
        end
        
        function value=get.PulseDurationInMsAsString(self)
            value=self.PulseDurationInMsAsString_;
        end
        
        function set.PulseDurationInMsAsString(self,newString)  % the duration of the pulse, in seconds.  The sweep duration is twice this.
            newValue=str2double(newString);
            if ~isnan(newValue) && 5<=newValue && newValue<=500,
                self.PulseDurationInMsAsString_=strtrim(newString);
                self.clearExistingSweepIfPresent_();
            end
            self.broadcast('Update');
        end

%         function command=get.Command(self)  % the command signal, in units geiven by the ChannelUnits property of the Stimulation object
%             t=self.Time;
%             delay=self.PulseDuration/2;
%             amplitude=self.Amplitude.toDouble();
%             command=amplitude*((delay<=t)&(t<delay+self.PulseDuration));
%             % command = ws.SingleStimulus( ...
%             %               ws.function.TestPulse('PulseDuration', self.PulseDuration, ...
%             %                                                 'PulseAmplitude', self.Amplitude ));                                                        
%         end                                                        

        function commands = getCommandPerElectrode(self, fs, amplitudePerElectrode)  
            % Command signal for each test pulser electrode, each in units given by the ChannelUnits property 
            % of the Stimulation object
            %t = self.Time ;  % col vector
            t = self.getTime(fs) ;  % col vector
            delay = self.PulseDuration/2 ;
            %amplitudePerElectrode = self.AmplitudePerElectrode ;  % row vector
            unscaledCommand = (delay<=t)&(t<delay+self.PulseDuration) ;  % col vector
            commands = bsxfun(@times, amplitudePerElectrode, unscaledCommand) ;
        end  
        
%         function commandInVolts=get.CommandInVolts(self)  % the command signal, in volts to be sent out the AO channel
%             command=self.Command;
%             inverseChannelScale=1/self.CommandChannelScale;
%             commandInVolts=command*inverseChannelScale;
%         end
        
        function commandsInVolts = getCommandInVoltsPerElectrode(self, fs, amplitudePerElectrode)  
            % the command signals, in volts to be sent out the AO channels
            %commands=self.CommandPerElectrode;   % (nScans x nCommandChannels)
            commands = self.getCommandPerElectrode(fs, amplitudePerElectrode) ;  % (nScans x nCommandChannels)
            commandChannelScales=self.CommandChannelScalePerElectrode;  % 1 x nCommandChannels
            inverseChannelScales=1./commandChannelScales;
            % zero any channels that have infinite (or nan) scale factor
            sanitizedInverseChannelScales=ws.fif(isfinite(inverseChannelScales), inverseChannelScales, zeros(size(inverseChannelScales)));
            commandsInVolts=bsxfun(@times,commands,sanitizedInverseChannelScales);
        end                                                        

        function value=get.DoSubtractBaseline(self)
            value=self.DoSubtractBaseline_;
        end
        
        function set.DoSubtractBaseline(self,newValue)
            if islogical(newValue) ,
                self.DoSubtractBaseline_=newValue;
                self.clearExistingSweepIfPresent_();
            end
            self.broadcast('Update');
        end
        
        function value=get.IsAutoY(self)
            value=self.IsAutoY_;
        end
        
        function set.IsAutoY(self,newValue)
            if islogical(newValue) ,
                self.IsAutoY_=newValue;
                if self.IsAutoY_ ,                
                    yLimits=self.automaticYLimits();
                    if ~isempty(yLimits) ,                    
                        self.YLimits_=yLimits;
                    end
                end
            end
            self.broadcast('Update');
        end
        
        function value=get.IsAutoYRepeating(self)
            value=self.IsAutoYRepeating_;
        end
        
        function set.IsAutoYRepeating(self,newValue)
            if islogical(newValue) && isscalar(newValue) ,
                self.IsAutoYRepeating_=newValue;
            end
            self.broadcast('Update');
        end
              
        function result=get.YUnits(self)
            result = self.MonitorUnits ;
        end
        
%         function value=get.SamplingRate(self)
%             value=self.SamplingRate_;
%         end
        
%         function value=get.Dt(self)  % s
%             value=1/self.SamplingRate_;
%         end
        
        function value = getTime(self, fs)  % s
            dt = 1/fs ;  % s
            nScansInSweep = self.getNScansInSweep(fs) ;
            value = dt*(0:(nScansInSweep-1))' ;  % s
        end
        
        function value = get.SweepDuration(self)  % s
            value = 2*self.PulseDuration ;
        end
        
        function value = getNScansInSweep(self, fs)
            dt = 1/fs ;  % s
            sweepDuration=2*self.PulseDuration;
            value=round(sweepDuration/dt);
        end
        
        function value=get.ElectrodeNames(self)
            ephys=self.Parent_;
            if isempty(ephys) ,
                em=[];
            else                
                em=ephys.ElectrodeManager;
            end
            if isempty(em) ,
                value=cell(1,0);
            else
                value=em.TestPulseElectrodeNames;
            end
        end
        
        function value=get.CommandChannelNames(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Stimulation.AnalogChannelNames;
        end

        function value=get.MonitorChannelNames(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Acquisition.ChannelNames;
        end
        
        function value=get.IsRunning(self)
            value=self.IsRunning_;
        end

        function value=get.CommandUnits(self)
            ephys = self.Parent_ ;
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.aoChannelUnitsFromName(ephys.TestPulseElectrodeCommandChannelName);            
        end
        
        function result=get.CommandUnitsPerElectrode(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            % commandChannelNames={testPulseElectrodes.CommandChannelName};
            commandChannelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            %stimulus=wavesurferModel.Stimulation;
            %result=ws.objectArray('ws.SIUnit',[1 n]);
            result = cell(1,n) ;
            for i=1:n ,
                unit=wavesurferModel.aoChannelUnitsFromName(commandChannelNames{i});
                result{i} = unit ;
%                 if ~isempty(unit) ,
%                     result(i)=unit;
%                 end
            end
        end  % function
        
        function value=get.MonitorUnits(self)
            ephys = self.Parent_ ;
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.aiChannelUnitsFromName(ephys.TestPulseElectrodeMonitorChannelName);           
        end  % function
        
        function result=get.MonitorUnitsPerElectrode(self)        
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %monitorChannelNames={testPulseElectrodes.MonitorChannelName};
            monitorChannelNames=cellfun(@(electrode)(electrode.MonitorChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            %acquisition=wavesurferModel.Acquisition;
            %result=ws.objectArray('ws.SIUnit',[1 n]);
            result = cell(1,n) ;
            for i=1:n ,
                unit = wavesurferModel.aiChannelUnitsFromName(monitorChannelNames{i}) ;
                result{i} = unit ;
%                 if ~isempty(unit) ,
%                     result(i)=unit;
%                 end
            end
        end  % function
        
        function result=get.IsVCPerElectrode(self) 
            % Returns a logical row array indicated whether each trode is
            % in VC mode.  Note that to be in VC mode, from the Test
            % Pulser's point of view, is a different matter from being in
            % VC mode from the Electrode Manager's point of view.  The EM
            % mode just determines which channels get used as command and
            % monitor for the electrode.  The TP only considers an
            % electrode to be in VC if the command units are commensurable
            % (summable) with Volts, and the monitor units are
            % commensurable with Amps.
            commandUnitsPerElectrode=self.CommandUnitsPerElectrode;
            monitorUnitsPerElectrode=self.MonitorUnitsPerElectrode;
            n=length(commandUnitsPerElectrode);
            result=false(1,n);
            for i=1:n ,
                commandUnits = commandUnitsPerElectrode{i} ;
                monitorUnits = monitorUnitsPerElectrode{i} ;
                areCommandUnitsCommensurateWithVolts = ~isempty(commandUnits) && isequal(commandUnits(end),'V') ;
                if areCommandUnitsCommensurateWithVolts ,
                    areMonitorUnitsCommensurateWithAmps = ~isempty(monitorUnits) && isequal(monitorUnits(end),'A') ;
                    result(i) = areMonitorUnitsCommensurateWithAmps ;
                else
                    result(i) = false ;
                end
%                 if i==1 , 
%                     volts=ws.SIUnit('V');
%                     amps=ws.SIUnit('A');
%                 end
%                 result(i)=areSummable(commandUnitsPerElectrode(i),volts) && ...
%                           areSummable(monitorUnitsPerElectrode(i),amps) ;
            end
        end  % function

        function result=get.IsCCPerElectrode(self) 
            % Returns a logical row array indicated whether each trode is
            % in CC mode.  Note that to be in CC mode, from the Test
            % Pulser's point of view, is a different matter from being in
            % VC mode from the Electrode Manager's point of view.  The EM
            % mode just determines which channels get used as command and
            % monitor for the electrode.  The TP only considers an
            % electrode to be in CC if the command units are commensurable
            % (summable) with amps, and the monitor units are
            % commensurable with volts.
            commandUnitsPerElectrode=self.CommandUnitsPerElectrode;
            monitorUnitsPerElectrode=self.MonitorUnitsPerElectrode;
            n=length(commandUnitsPerElectrode);
            result=false(1,n);
            for i=1:n ,
                commandUnits = commandUnitsPerElectrode(i) ;
                monitorUnits = monitorUnitsPerElectrode(i) ;
                areCommandUnitsCommensurateWithAmps = ~isempty(commandUnits) && isequal(commandUnits(end),'A') ;
                if areCommandUnitsCommensurateWithAmps ,
                    areMonitorUnitsCommensurateWithVolts = ~isempty(monitorUnits) && isequal(monitorUnits(end),'V') ;
                    result(i) = areMonitorUnitsCommensurateWithVolts ;
                else
                    result(i) = false ;
                end                
%                 if i==1 , 
%                     volts=ws.SIUnit('V');
%                     amps=ws.SIUnit('A');
%                 end
%                 result(i)=areSummable(commandUnitsPerElectrode(i),amps) && ...
%                           areSummable(monitorUnitsPerElectrode(i),volts) ;
            end
        end  % function

        function value=get.IsVC(self)
            commandUnits=self.CommandUnits;
            monitorUnits=self.MonitorUnits;
            if isempty(commandUnits) || isempty(monitorUnits) ,
                value=false;
            else
                value = isequal(commandUnits(end),'V') && isequal(monitorUnits(end),'A') ;
%                 areSummable(commandUnits,ws.SIUnit('V')) && ...
%                       areSummable(monitorUnits,ws.SIUnit('A')) ;
            end
        end  % function

        function value=get.IsCC(self)
            commandUnits=self.CommandUnits;
            monitorUnits=self.MonitorUnits;
            if isempty(commandUnits) || isempty(monitorUnits) ,
                value=false;
            else
                value = isequal(commandUnits(end),'A') && isequal(monitorUnits(end),'V') ;
%                 value=areSummable(commandUnits,ws.SIUnit('A')) && ...
%                       areSummable(monitorUnits,ws.SIUnit('V')) ;
            end
        end

%         function value=get.ResistanceUnits(self)
%             if self.IsCC ,
%                 value=self.GainUnits;
%             elseif self.IsVC , 
%                 value=1/self.GainUnits;                
%             else
%                 value=ws.SIUnit.empty();
%             end
%         end
        
%         function value=get.ResistanceUnitsPerElectrode(self)
%             value=self.GainUnitsPerElectrode;
%             value(self.IsVCPerElectrode)=1./value(self.IsVCPerElectrode);
%             % for elements that are not convertible to resistance, just
%             % leave as gain
%         end
        
%         function value=get.GainUnits(self)
%             if isempty(self.Electrode_)
%                 value=ws.SIUnit.empty();                
%             else
%                 value=(self.MonitorUnits/self.CommandUnits);
%             end
%         end
        
%         function value=get.GainUnitsPerElectrode(self)
%             value=(self.MonitorUnitsPerElectrode./self.CommandUnitsPerElectrode);
%         end
        
%         function value=get.GainOrResistanceUnits(self)
%             if self.IsCC || self.IsVC ,
%                 value=self.ResistanceUnits;
%             else
%                 value=self.GainUnits;
%             end
%         end
        
        function result = getGainOrResistanceUnitsPerElectrode_(self)
            if self.IsRunning_ ,
                result = self.GainOrResistanceUnitsPerElectrodeCached_ ;
            else
                resultIfCC = ws.divideUnits(self.MonitorUnitsPerElectrode,self.CommandUnitsPerElectrode);
                resultIfVC = ws.divideUnits(self.CommandUnitsPerElectrode,self.MonitorUnitsPerElectrode);
                isVCPerElectrode = self.IsVCPerElectrode ;
                result = ws.fif(isVCPerElectrode, resultIfVC, resultIfCC) ;
            end
        end
        
        function value=getGainOrResistancePerElectrode_(self)
            value=self.GainOrResistancePerElectrode_;
        end
        
%         function [gainOrResistance,gainOrResistanceUnits] = getGainOrResistancePerElectrodeWithNiceUnits_(self)
%             rawGainOrResistance = self.getGainOrResistancePerElectrode_() ;
%             rawGainOrResistanceUnits = self.getGainOrResistanceUnitsPerElectrode_() ;
%             % [gainOrResistanceUnits,gainOrResistance] = rawGainOrResistanceUnits.convertToEngineering(rawGainOrResistance) ;  
%             [gainOrResistanceUnits,gainOrResistance] = ...
%                 ws.convertDimensionalQuantityToEngineering(rawGainOrResistanceUnits,rawGainOrResistance) ;
%         end
        
        function value=get.UpdateRate(self)
            value=self.UpdateRate_;
        end
        
%         function value=get.Resistance(self)
%             if isempty(self.Electrode_)
%                 value=zeros(1,0); 
%             else
%                 %isElectrode=(self.Electrode_==self.Electrodes);
%                 isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
%                 value=self.ResistancePerElectrode_(isElectrode);
%             end
%         end
%         
%         function value=get.Gain(self)
%             if isempty(self.Electrode_)
%                 value=zeros(1,0); 
%             else
%                 %isElectrode=(self.Electrode_==self.Electrodes);
%                 isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
%                 value=self.GainPerElectrode_(isElectrode);
%             end
%         end
%         
%         function value=get.GainOrResistance(self)
%             if self.IsVC || self.IsCC ,
%                 value=self.Resistance;
%             else
%                 value=self.Gain;
%             end
%         end
        
%         function value=get.Monitor(self)
%             if isempty(self.ElectrodeName_)
%                 value=nan(self.NScansInSweep,1); 
%             else
%                 % isElectrode=(self.Electrode_==self.Electrodes);
%                 isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
%                 value=self.MonitorPerElectrode_(:,isElectrode);
%             end
%         end
        
%         function value=get.InputDeviceNames(self)
%             wavesurferModel=self.Parent.Parent;            
%             value=wavesurferModel.Acquisition.AnalogDeviceNames ;
%         end
%         
%         function value=get.OutputDeviceNames(self)
%             wavesurferModel=self.Parent.Parent;
%             value=wavesurferModel.Stimulation.AnalogDeviceNames ;
%         end
        
        function result=get.CommandTerminalIDPerElectrode(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %commandChannelNames={testPulseElectrodes.CommandChannelName};
            commandChannelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            stimulationSubsystem=wavesurferModel.Stimulation;
            result=zeros(1,n);
            for i=1:n ,
                thisCommandChannelName = commandChannelNames{i} ;
                thisTerminalID = stimulationSubsystem.analogTerminalIDFromName(thisCommandChannelName) ;
                result(i) = thisTerminalID ;
            end
        end
        
        function result=get.MonitorTerminalIDPerElectrode(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %monitorChannelNames={testPulseElectrodes.MonitorChannelName};
            monitorChannelNames=cellfun(@(electrode)(electrode.MonitorChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            acquisition=wavesurferModel.Acquisition;
            result=zeros(1,n);
            for i=1:n ,
                result(i)=acquisition.analogTerminalIDFromName(monitorChannelNames{i});
            end
        end
        
%         function value=get.MonitorTerminalID(self)
%             wavesurferModel=self.Parent_.Parent;
%             value=wavesurferModel.Acquisition.analogTerminalIDFromName(self.MonitorChannelName);            
%         end
        
%         function value=get.MonitorChannelScale(self)
%             wavesurferModel=self.Parent_.Parent;
%             value=wavesurferModel.aiChannelScaleFromName(self.MonitorChannelName);
%         end
%         
%         function value=get.CommandChannelScale(self)
%             wavesurferModel=self.Parent_.Parent;
%             value=wavesurferModel.aoChannelScaleFromName(self.CommandChannelName);
%         end
        
        function result=get.CommandChannelScalePerElectrode(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %commandChannelNames={testPulseElectrodes.CommandChannelName};
            commandChannelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            %stimulus=wavesurferModel.Stimulation;
            result=zeros(1,n);
            for i=1:n ,
                result(i)=wavesurferModel.aoChannelScaleFromName(commandChannelNames{i});
            end
        end
        
        function result=get.MonitorChannelScalePerElectrode(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %monitorChannelNames={testPulseElectrodes.MonitorChannelName};
            monitorChannelNames=cellfun(@(electrode)(electrode.MonitorChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            %acquisition=wavesurferModel.Acquisition;
            result=zeros(1,n);
            for i=1:n ,
                result(i)=wavesurferModel.aiChannelScaleFromName(monitorChannelNames{i});
            end
        end
        
%         function value=get.AreYLimitsForRunDetermined(self)
%             value=self.AreYLimitsForRunDetermined_;
%         end

        function yLimits=automaticYLimits(self)
            % Trys to determine the automatic y limits from the monitor
            % signal.  If succful, returns them.  If unsuccessful, returns empty.
            if self.IsRunning_ ,
                monitorMax=max(self.MonitorCached_);
                monitorMin=min(self.MonitorCached_);
            else
                monitor=self.Monitor;
                monitorMax=max(monitor);
                monitorMin=min(monitor);
            end
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
        end  % function

        function set.YLimits(self,newValue)
            if isnumeric(newValue) && isequal(size(newValue),[1 2]) && all(isfinite(newValue)) && newValue(1)<newValue(2),
                self.YLimits_=newValue;
            end
            self.broadcast('Update');
        end
        
        function result=get.YLimits(self)
            result=self.YLimits_;
        end

        function electrodeWasAdded(self, electrode)
            % Called by the parent Ephys when an electrode is added.

            %self.NElectrodes_ = nTestPulseElectrodes ;
            % Redimension MonitorPerElectrode_ appropriately, etc.
            self.clearExistingSweepIfPresent_()

            % If there's no current electrode, set Electrode to point to
            % the newly-created one.            
            if isempty(self.ElectrodeName) ,
                self.ElectrodeName = electrode.Name ; 
            end
        end

        function electrodesRemoved(self)
            % Called by the parent Ephys when one or more electrodes are
            % removed.
            
            % Redimension MonitorPerElectrode_ appropriately, etc.
            %self.NElectrodes_ = nTestPulseElectrodes ;
            self.clearExistingSweepIfPresent_()
            
            % Change the electrode if needed
            self.changeElectrodeIfCurrentOneIsNotAvailable_();
        end  % function
        
        function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSD>
            % Called by the parent Ephys to notify the TestPulser of a
            % change.
%             if (self.Electrode == electrode) ,  % pointer comparison, essentially
%                 self.Electrode=electrode;  % call the setter to change everything that should change
%             end
            self.broadcast('Update') ;
        end  % function
        
        function isElectrodeMarkedForTestPulseMayHaveChanged(self)
            % Redimension MonitorPerElectrode_ appropriately, etc.
            %self.NElectrodes_ = nTestPulseElectrodes ;
            self.clearExistingSweepIfPresent_()
            
            % Change the electrode if needed
            self.changeElectrodeIfCurrentOneIsNotAvailable_();
        end  % function
        
        function start_(self, indexOfTestPulseElectrodeWithinTestPulseElectrodes, electrode, amplitudePerTestPulseElectrode, fs, nTestPulseElectrodes, ...
                        gainOrResistanceUnitsPerTestPulseElectrode)
            % fprintf('Just entered start()...\n');
            if self.IsRunning ,
                % fprintf('About to exit start() via short-circuit...\n');                                            
                return
            end

            try
                % Takes some time to start...
                self.changeReadiness(-1);
                %self.IsReady_ = false ;
                %self.broadcast('UpdateReadiness');

                % Get some handles we'll need
                %electrode=self.Electrode;
                ephys=self.Parent;
                electrodeManager=ephys.ElectrodeManager;
                wavesurferModel=[];
                if ~isempty(ephys) ,
                    wavesurferModel=ephys.Parent;
                end                

                % Update the smart electrode channel scales, if possible and
                % needed
                if ~isempty(electrodeManager) ,
                    if electrodeManager.DoTrodeUpdateBeforeRun
                        electrodeManager.updateSmartElectrodeGainsAndModes();
                    end
                end

                % Check that we can start, and if not, return
                canStart = ...
                    ~isempty(electrode) && ...
                    electrodeManager.areAllElectrodesTestPulsable() && ...
                    electrodeManager.areAllMonitorAndCommandChannelNamesDistinct() && ...
                    (isempty(wavesurferModel) || isequal(wavesurferModel.State,'idle')) ;
                if ~canStart,
                    return
                end

    %             % If present, notify the wavesurferModel that we're about to start
    %             if ~isempty(wavesurferModel) ,
    %                 wavesurferModel.willPerformTestPulse();
    %             end

                % Free up resources we will need for test pulsing
                if ~isempty(wavesurferModel) ,
                    wavesurferModel.testPulserIsAboutToStartTestPulsing();
                end
                
                % Get the stimulus
                commandsInVolts = self.getCommandInVoltsPerElectrode(fs, amplitudePerTestPulseElectrode) ;
                nScans=size(commandsInVolts,1);
                nElectrodes=size(commandsInVolts,2);

                % Set up the input task
                % fprintf('About to create the input task...\n');
                self.InputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Input');
                monitorTerminalIDs=self.MonitorTerminalIDPerElectrode;
                for i=1:nElectrodes ,
                    self.InputTask_.createAIVoltageChan(self.DeviceName_, monitorTerminalIDs(i));  % defaults to differential
                end
                deviceName = self.Parent.Parent.DeviceName ;
                clockString=sprintf('/%s/ao/SampleClock',deviceName);  % device name is something like 'Dev3'
                self.InputTask_.cfgSampClkTiming(fs,'DAQmx_Val_ContSamps',[],clockString);
                  % set the sampling rate, and use the AO sample clock to keep
                  % acquisiton synced with analog output
                self.InputTask_.cfgInputBuffer(10*nScans);

                % Set up the output task
                % fprintf('About to create the output task...\n');
                self.OutputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Output');
                commandTerminalIDs=self.CommandTerminalIDPerElectrode;
                for i=1:nElectrodes ,
                    self.OutputTask_.createAOVoltageChan(self.DeviceName_, commandTerminalIDs(i));
                end
                self.OutputTask_.cfgSampClkTiming(fs,'DAQmx_Val_ContSamps',nScans);

                % Limit the stimulus to the allowable range
                limitedCommandsInVolts=max(-10,min(commandsInVolts,+10));

                % Write the command to the output task                
                self.OutputTask_.writeAnalogData(limitedCommandsInVolts);

                % Set up the input task callback
                %nSamplesPerSweep=nScans*nElectrodes;
                self.InputTask_.everyNSamples=nScans;
                self.InputTask_.everyNSamplesEventCallbacks=@(varargin)(self.completingSweep());

                % Cache some things for speed during sweeps
                isVCPerElectrode = self.IsVCPerElectrode ;
                self.IsVCPerElectrodeCached_ = isVCPerElectrode ;
                self.IsCCPerElectrodeCached_=self.IsCCPerElectrode;
                self.MonitorChannelInverseScalePerElectrodeCached_=1./self.MonitorChannelScalePerElectrode;
                %self.CommandChannelScalePerElectrodeCached_=self.CommandChannelScalePerElectrode;
                self.AmplitudePerElectrodeCached_ = amplitudePerTestPulseElectrode ;
                self.IndexOfElectrodeWithinTPElectrodesCached_ = indexOfTestPulseElectrodeWithinTestPulseElectrodes ;
                self.NScansInSweepCached_ = self.getNScansInSweep(fs) ;
                self.NElectrodesCached_ = nTestPulseElectrodes ;
                self.GainOrResistanceUnitsPerElectrodeCached_ = gainOrResistanceUnitsPerTestPulseElectrode ;
                self.SamplingRateCached_ = fs ;

                % Compute some indices and cache them, again for speed during
                % sweeps
                totalDuration=self.SweepDuration;  % s
                t0Base=0; % s
                tfBase=1/8*totalDuration; % s
                t0Pulse=5/8*totalDuration; % s
                tfPulse=6/8*totalDuration; % s
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
                        self.NSweepsPerAutoY_ =  min(1,round(1/(self.SweepDuration * self.DesiredRateOfAutoYing_))) ;
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

                % Finish up the start
                self.NSweepsCompletedThisRun_=0;
                self.IsRunning_=true;
                %self.broadcast('Update');

                % If present, notify the wavesurferModel that we're about to start
                % This causes essentially all windows to update(), so we don't
                % need to separately broadcast that TestPulser has changed
                if ~isempty(wavesurferModel) ,
                    wavesurferModel.willPerformTestPulse();
                end

                % Set up timing
                self.TimerValue_=tic();
                self.LastToc_=toc(self.TimerValue_);

                % OK, now we consider ourselves no longer busy
                self.changeReadiness(+1);
                %self.IsReady_ = true ;
                %self.broadcast('UpdateReadiness');

                % actually start the data acq tasks
                self.InputTask_.start();  % won't actually start until output starts b/c see above
                self.OutputTask_.start();
            catch me
                %fprintf('probelm with output task start\n');
                self.abort_();
                self.changeReadiness(+1);
                rethrow(me);
            end
            
            % fprintf('About to exit start()...\n');
        end  % function
        
        function stop_(self)
            % This is what gets called when the user presses the 'Stop' button,
            % for instance.
            %fprintf('Just entered stop()...\n');            
            if ~self.IsRunning ,
                %fprintf('About to exit stop() via short-circuit...\n');                            
                return
            end
            
            try 
                % Takes some time to stop...
                self.changeReadiness(-1);
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

                % Notify the rest of Wavesurfer
                ephys=self.Parent;
                wavesurferModel=[];
                if ~isempty(ephys) ,
                    wavesurferModel=ephys.Parent;
                end                
                if ~isempty(wavesurferModel) ,
                    wavesurferModel.didPerformTestPulse();
                end

                % Takes some time to stop...
                self.changeReadiness(+1);
                %self.IsReady_ = true ;
                %self.broadcast('Update');
            catch me
                self.abort_();
                self.changeReadiness(+1);
                rethrow(me);
            end
        end  % function
    end  % public methods
        
    methods (Access=protected)
        function abort_(self)
            % This is called when a problem arises during test pulsing, and we
            % want to try very hard to get back to a known, sane, state.

            % And now we are once again ready to service method calls...
            self.changeReadiness(-1);

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

            % Notify the rest of Wavesurfer
            ephys=self.Parent;
            wavesurferModel=[];
            if ~isempty(ephys) ,
                wavesurferModel=ephys.Parent;
            end                
            if ~isempty(wavesurferModel) ,
                wavesurferModel.didAbortTestPulse();
            end
            
            % And now we are once again ready to service method calls...
            self.changeReadiness(+1);
        end  % function
    end
    
    methods
%         function set.IsRunning(self,newValue)
%             if islogical(newValue) && isscalar(newValue),
%                 if self.IsRunning, 
%                     if ~newValue ,
%                         self.stop();
%                     end
%                 else
%                     if newValue ,
%                         self.start();
%                     end
%                 end
%             end
%         end  % function
        
%         function toggleIsRunning(self)
%             if self.IsRunning ,
%                 self.stop();
%             else
%                 self.start();
%             end
%         end  % function
        
        function completingSweep(self,varargin)
            % compute resistance
            % compute delta in monitor
            % Specify the time windows for measuring the baseline and the pulse amplitude
            %fprintf('Inside TestPulser::completingSweep()\n');
            rawMonitor=self.InputTask_.readAnalogData(self.NScansInSweepCached_);  % rawMonitor is in V, is NScansInSweep x NElectrodes
                % We now read exactly the number of scans we expect.  Not
                % doing this seemed to work fine on ALT's machine, but caused
                % nasty jitter issues on Minoru's rig machine.  In retrospect, kinda
                % surprising it ever worked without specifying this...
            %sz=size(rawMonitor)
            %self.NScansInSweep
            %self.NElectrodes
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
%             self.GainOrResistancePerElectrode_=zeros(1,self.NElectrodesCached_);
%             for i=1:length(self.GainOrResistancePerElectrode_)
%                 if self.IsVCPerElectrodeCached_(i) ,
%                     self.GainOrResistancePerElectrode_(i)=1./self.GainPerElectrode_(i);  % command is a voltage, so gain is a conductance
%                 else
%                     self.GainOrResistancePerElectrode_(i)=self.GainPerElectrode_(i);  % if CC, this is resistance, if neither CC nor VC, it's gain
%                 end
%             end
            %gainOrResistance=self.gainOrResistance
            %fprintf('R: %g %s\n',self.Resistance,string(self.ResistanceUnits))
            %if self.NSweepsCompletedThisRun_==0 ,  % temporary for debugging!!!
            if self.DoSubtractBaseline_ ,
                self.MonitorPerElectrode_=bsxfun(@minus,scaledMonitor,base);
            else
                self.MonitorPerElectrode_=scaledMonitor;
            end
            self.MonitorCached_=self.MonitorPerElectrode_(:,self.IndexOfElectrodeWithinTPElectrodesCached_);
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
            
            self.broadcast('UpdateTrace');
            %fprintf('About to exit TestPulser::completingSweep()\n');            
        end  % function
        
%         function mimic(self, other)
%             % Note that this uses the high-level setters, so it will cause
%             % any subscribers to get (several) MayHaveChanged events.
%             self.PulseDurationInMsAsString=other.PulseDurationInMsAsString;
%             self.DoSubtractBaseline=other.DoSubtractBaseline;
%             self.IsAutoY=other.IsAutoY;
%             electrodeName=other.ElectrodeName;
%             %keyboard
%             self.ElectrodeName=electrodeName;
%         end
        
        function zoomIn(self)
            yLimits=self.YLimits;
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+0.5*yRadius*[-1 +1];
            self.YLimits=newYLimits;
        end  % function
        
        function zoomOut(self)
            yLimits=self.YLimits;
            yMiddle=mean(yLimits);
            yRadius=0.5*diff(yLimits);
            newYLimits=yMiddle+2*yRadius*[-1 +1];
            self.YLimits=newYLimits;
        end  % function
        
        function scrollUp(self)
            yLimits=self.YLimits;
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle+0.1*ySpan)+yRadius*[-1 +1];
            self.YLimits=newYLimits;
        end  % function
        
        function scrollDown(self)
            yLimits=self.YLimits;
            yMiddle=mean(yLimits);
            ySpan=diff(yLimits);
            yRadius=0.5*ySpan;
            newYLimits=(yMiddle-0.1*ySpan)+yRadius*[-1 +1];
            self.YLimits=newYLimits;
        end  % function
                
        function didSetAcquisitionSampleRate(self, newValue)  %#ok<INUSD>
            % newValue has already been validated
            %self.setSamplingRate_(newValue) ;  % This will fire Update, etc.
            self.clearExistingSweepIfPresent_() ;        
        end       
        
        function didSetIsInputChannelActive(self) 
            self.broadcast('DidSetIsInputChannelActive');
        end
        
        function clearExistingSweepIfPresent_(self)
            self.MonitorPerElectrode_ = [] ;
            self.GainPerElectrode_ = [] ;
            self.GainOrResistancePerElectrode_ = [] ;
            self.UpdateRate_ = nan ;
        end  % function
    end  % methods
        
    methods (Access=protected)        
        function tryToSetYLimitsIfCalledFor_(self)
            % If setting the y limits is appropriate right now, try to set them
            % Sets AreYLimitsForRunDetermined_ and YLimits_ if successful.
            if self.IsRunning ,
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
        
%         function autosetYLimits_(self)
%             % Syncs the Y limits to the monitor signal, if self is in the
%             % right mode and the monitor signal is well-behaved.
%             if self.IsYAuto_ ,
%                 automaticYLimits=self.automaticYLimits();
%                 if ~isempty(automaticYLimits) ,
%                     self.YLimits_=automaticYLimits;
%                 end
%             end
%         end

        function changeElectrodeIfCurrentOneIsNotAvailable_(self)
            % Checks that the Electrode_ is still a valid choice.  If not,
            % tries to find another one.  If that also fails, sets
            % Electrode_ to empty.  Also, if Electrode_ is empty but there
            % is at least one test pulse electrode, makes Electrode_ point
            % to the first test pulse electrode.
            electrodes=self.Parent.ElectrodeManager.TestPulseElectrodes;
            if isempty(electrodes)
                self.ElectrodeName='';
            else
                if isempty(self.ElectrodeName) ,
                    electrode = electrodes{1} ;
                    self.ElectrodeName = electrode.Name;  % no current electrode, but electrodes is nonempty, so make the first one current.
                else
                    % If we get here, self.Electrode is a scalar of class
                    % Electrode, and electrode is a nonempty cell array of
                    % scalars of class Electrode
                    isMatch=cellfun(@(electrode)(isequal(self.ElectrodeName, electrode.Name)),electrodes);
                    if any(isMatch)
                        % nothing to do here---self.Electrode is a handle
                        % that points to a current test pulse electrode
                    else
                        % It seems the current electrode has been deleted, or is
                        % not marked as being available for test pulsing
                        electrode = electrodes{1} ;
                        self.ElectrodeName = electrode.Name ;
                    end
                end
            end 
        end  % function
        
%         function setSamplingRate_(self,newValue)  % in Hz
%             if isnumeric(newValue) && isscalar(newValue) && isfinite(newValue) && newValue>0 ,
%                 self.SamplingRate_ = newValue ;
%                 self.clearExistingSweepIfPresent_() ;                
%             end
%             self.broadcast('Update') ;
%         end
    end  % protected methods block
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();
%         mdlHeaderExcludeProps = {};
%     end    
    
    % These next two methods allow access to private and protected variables from ws.Coding. 
    methods (Access=protected)
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
%     methods
%         % Have to override decodeProperties() to sync up transient properties
%         % after.
%         function decodeProperties(self, encoding)
%             decodeProperties@ws.Coding(self, encoding) ;
%             self.clearExistingSweepIfPresent_();  % need to resync some transient properties to the "new" self
%         end  % function
%     end
    
    methods (Access=protected)
        % Have to override decodeUnwrappedEncodingCore_() to sync up transient properties
        % after.
        function decodeUnwrappedEncodingCore_(self, encoding)
            decodeUnwrappedEncodingCore_@ws.Coding(self, encoding) ;
            self.clearExistingSweepIfPresent_();  % need to resync some transient properties to the "new" self
        end  % function
    end
    
    methods
        function didSetDeviceName(self, deviceName)
            %fprintf('ws.Triggering::didSetDevice() called\n') ;
            %dbstack
            self.DeviceName_ = deviceName ;
        end        
        
%         function result = get.NElectrodes(self)
%             result = self.NElectrodes_ ;
%         end
        
        function result = getMonitorPerElectrode_(self)
            result = self.MonitorPerElectrode_ ;
        end
    end
    
end  % classdef
