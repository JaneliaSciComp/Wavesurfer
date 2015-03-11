classdef TestPulser < ws.Model & ws.Mimic  % & ws.EventBroadcaster (was before Mimic)
    properties  (Access=protected)  % a lot of these props should have Transient=true
        Parent_  % an Ephys object
        ElectrodeName_  
          % a local place to store the ElectrodeName, which gets persisted, unlike Electrode_
          % Invariant: isempty(self.Electrode_) ||
          %            isequal(self.Electrode_.Name,self.ElectrodeName_)
        %CommandChannelName_
        %MonitorChannelName_
        %AmplitudeAsString_  % in units of the electrode command channel
        PulseDurationInMsAsString_  % the duration of the pulse, in ms.  The trial duration is twice this.
        DoSubtractBaseline_
        SamplingRate_  % in Hz
        IsRunning_
        %Gain_  % in units given by GainUnits
        %Resistance_  % in units given by ResistanceUnits
        %Monitor_  % the monitor channel signal for the current trial
        UpdateRate_
        NSweepsCompletedThisRun_
        InputTask_
        OutputTask_
        TimerValue_
        LastToc_
        YLimits_
        IsAutoY_  % if true, the y limits are synced to the monitor signal currently in view
        AreYLimitsForRunDetermined_  %  whether the proper y limits for the ongoing run have been determined
        IsCCCached_  % true iff the electrode is in current-clamp mode, cached for speed when acquiring data
        IsVCCached_  % true iff the electrode is in voltage-clamp mode, cached for speed when acquiring data
        %MonitorChannelScaleCached_=nan
        %CommandChannelScaleCached_=nan
        AmplitudeAsDoublePerElectrodeCached_  % cached double version of AmplitudeAsDoublePerElectrode, for speed during trials
        IsCCPerElectrodeCached_  
        IsVCPerElectrodeCached_  
        MonitorChannelInverseScalePerElectrodeCached_
        %CommandChannelScalePerElectrodeCached_
        GainPerElectrode_
        GainOrResistancePerElectrode_
        MonitorPerElectrode_
        ElectrodeIndexCached_
        MonitorCached_  % a cache of the monitor signal for the current electrode
        %SweepDurationCached_;  % s
        NScansInSweepCached_;
        NElectrodesCached_;
        %DtCached_;  % s
        I0BaseCached_;
        IfBaseCached_;
        I0PulseCached_;
        IfPulseCached_;
        %IsStopping_
    end
    
    properties  (Access=protected, Transient=true)
        Electrode_  % the current electrode, or empty if there isn't one        
    end
    
    properties (Dependent=true, Hidden=true)
        Parent
        Electrode
        ElectrodeName
        Amplitude  % a DoubleString, in units of the electrode command channel
        PulseDurationInMsAsString  % the duration of the pulse, in ms.  The trial duration is twice this.
        DoSubtractBaseline
        IsAutoY
        YLimits
        IsRunning
    end
    
    properties (Dependent = true, SetAccess = immutable, Hidden=true)
        CommandChannelName  % For the current electrode
        MonitorChannelName  % For the current electrode
        Dt  % s
        SweepDuration  % s
        NScansInSweep
        Time  % s
        ElectrodeNames
        CommandChannelNames
        MonitorChannelNames
        PulseDuration  % s
        Gain  % in units given by ResistanceUnits
        Resistance  % in units given by ResistanceUnits
        GainOrResistance
        SamplingRate  % in Hz
        CommandUnits
        MonitorUnits
        GainUnits
        ResistanceUnits
        GainOrResistanceUnits
        IsCC
        IsVC
        UpdateRate
        Monitor
        %Command
        %CommandInVolts
        NSweepsCompletedThisRun
        OutputDeviceNames
        CommandChannelID
        InputDeviceNames
        MonitorChannelID
        MonitorChannelScale
        CommandChannelScale
        AreYLimitsForRunDetermined
        AutomaticYLimits
        Electrodes
        NElectrodes
        AmplitudeAsDoublePerElectrode
        CommandPerElectrode
        CommandChannelScalePerElectrode
        MonitorChannelScalePerElectrode
        CommandInVoltsPerElectrode
        CommandChannelIDPerElectrode
        MonitorChannelIDPerElectrode
        IsCCPerElectrode
        IsVCPerElectrode
        CommandUnitsPerElectrode
        MonitorUnitsPerElectrode
        ElectrodeIndex
        GainUnitsPerElectrode
        %ResistanceUnitsPerElectrode
        GainOrResistanceUnitsPerElectrode
        GainOrResistancePerElectrode
    end
    
    properties (Dependent=true)
        ElectrodeMode  % mode of the current electrode
    end
    
    events
        %MayHaveChanged
        UpdateTrace
    end
    
    methods
        function self = TestPulser(varargin)
            % Process args
            validPropNames=ws.most.util.findPropertiesSuchThat(self,'SetAccess','public');
            mandatoryPropNames=cell(1,0);
            pvArgs = ws.most.util.filterPVArgs(varargin,validPropNames,mandatoryPropNames);
            propNamesRaw = pvArgs(1:2:end);
            propValsRaw = pvArgs(2:2:end);
            nPVs=length(propValsRaw);  % Use the number of vals in case length(varargin) is odd
            propNames=propNamesRaw(1:nPVs);
            propVals=propValsRaw(1:nPVs);            
            
            % Set the properties
            for idx = 1:nPVs
                self.(propNames{idx}) = propVals{idx};
            end
            
            %self.Parent_=ephys;
            
            ephys=[];
            electrodeManager=[];
            electrodes=cell(0,1);
            electrode=[];
            if ~isempty(self.Parent_)
                ephys=self.Parent_;
            end
            if ~isempty(ephys)
                electrodeManager=ephys.ElectrodeManager;
            end
            if ~isempty(electrodeManager)
                electrodes=electrodeManager.TestPulseElectrodes;
            end
            if ~isempty(electrodes) ,
                electrode=electrodes{1};
            end           
            self.Electrode_=electrode;

            self.PulseDurationInMsAsString_='10';  % ms
            %self.Amplitude_='10';  % units determined by electrode mode, channel units
            %self.AmplitudeAsDouble_=self.Amplitude.toDouble();  % keep around in this form for speed during trials
            self.DoSubtractBaseline_=true;
            self.IsAutoY_=true;
            self.YLimits_=[-10 +10];
            self.SamplingRate_=20e3;  % Hz
            self.IsRunning_=false;
            %self.Gain_=nan;
            %self.Resistance_=nan;
            self.UpdateRate_=nan;
            %self.ResistanceUnits=ws.utility.SIUnit();
            %self.command = ws.stimulus.SingleStimulus( ...
            %                   ws.stimulus.function.TestPulse('PulseDuration', self.PulseDuration, ...
            %                                                     'PulseAmplitude', self.Amplitude ));
            self.MonitorPerElectrode_=nan(self.NScansInSweep,self.NElectrodes);
            %self.nScansInMonitor=nan;  % only matters in the midst of an experiment
            self.IsCCCached_=nan;  % only matters in the midst of an experiment
            self.IsVCCached_=nan;  % only matters in the midst of an experiment            
            %self.IsStopping_=false;
            
%             % add listeners on host events
%             if ~isempty(ephys) ,
%                 wavesurferModel=ephys.Parent;
%                 if ~isempty(wavesurferModel) ,
%                     acquisition=wavesurferModel.Acquisition;
%                     stimulus=wavesurferModel.Stimulation;
%                 end
%                 if ~isempty(acquisition)
%                     acquisition.subscribeMe(self,'DidSetAnalogChannelUnitsOrScales');
%                 end
%                 if ~isempty(stimulus)
%                     stimulus.subscribeMe(self,'DidSetAnalogChannelUnitsOrScales');
%                 end
%             end
        end
        
%         % This is designed to be called by an EventBroadcaster if a
%         % subscribed-to event happens
%         function eventHappened(self,broadcaster,eventName,propertyName,source,event)   %#ok<INUSD,INUSL>
%             if isequal(eventName,'DidSetAnalogChannelUnitsOrScales')
%                 self.clearExistingSweepIfPresent();
%                 self.broadcast('Update');
%             end
%         end
        
        function self=didSetChannelUnitsOrScales(self)
            self.clearExistingSweepIfPresent();
            self.broadcast('Update');            
        end
                
        function delete(self)
            self.Parent_=[];
        end
        
        function value=get.Parent(self)
            value=self.Parent_;
        end

        function set.Parent(self,newValue)
            if isempty(newValue) || isa(newValue,'ws.system.Ephys') ,
                self.Parent_=newValue;
            end
        end
        
        function value=get.Electrode(self)
            value=self.Electrode_;
        end

        function set.Electrode(self,electrode)
            if isempty(electrode) ,
                self.ElectrodeName = '';
            else
                self.ElectrodeName = electrode.Name;
            end
            %self.Electrode_=electrode;
            %self.ElectrodeName_ = electrode.Name;
            %self.broadcast('Update');
        end        
        
        function value=get.ElectrodeName(self)
            value=self.ElectrodeName_;
%             if isempty(self.Electrode_) ,
%                 value=self.ElectrodeName_;
%                 %value='';
%             else
%                 value=self.Electrode_.Name;
%             end
        end

        function set.ElectrodeName(self,newValue)
            if isempty(newValue) ,
                self.ElectrodeName_ = '';
                self.Electrode_ = [];                
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
                        self.Electrode_ = [];
                    else
                        electrode=electrodeManager.getElectrodeByName(electrodeName);
                        self.ElectrodeName_ = electrodeName;
                        self.Electrode_ = electrode;
                    end
                end
            end
            self.broadcast('Update');
        end
        
        function result=get.Electrodes(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            result=electrodeManager.TestPulseElectrodes;
        end
        
        function value=get.CommandChannelName(self)
            electrode=self.Electrode_;
            if isempty(electrode) ,
                value='';
            else
                value=electrode.CommandChannelName;
            end
        end
        
%         function set.CommandChannelName(self,newValue)
%             channelNames=self.Parent_.Stimulation.ChannelNames;
%             newValueFiltered=channelNames(strcmp(newValue,channelNames));
%             if ~isempty(newValueFiltered) ,
%                 self.CommandChannelName_=newValueFiltered;
%                 self.clearExistingSweepIfPresent();
%             end
%             self.broadcast('Update');
%         end
        
        function value=get.MonitorChannelName(self)
            electrode=self.Electrode_;
            if isempty(electrode) ,
                value='';
            else
                value=electrode.MonitorChannelName;
            end
        end
        
%         function set.MonitorChannelName(self,newValue)
%             channelNames=self.Parent_.Acquisition.ChannelNames;
%             newValueFiltered=channelNames(strcmp(newValue,channelNames));
%             if ~isempty(newValueFiltered) ,
%                 self.MonitorChannelName_=newValueFiltered;
%                 self.clearExistingSweepIfPresent();
%             end
%             self.broadcast('Update');
%         end        
        
        function value=get.NSweepsCompletedThisRun(self)
            value=self.NSweepsCompletedThisRun_;
        end
        
        function result=get.NElectrodes(self)
            % Get the amplitudes of the test pulse for all the
            % marked-for-test-pulsing electrodes, as a double array.            
            ephys=self.Parent_;
            if isempty(ephys) ,
                result=0;
            else
                electrodeManager=ephys.ElectrodeManager;
                if isempty(electrodeManager) ,
                    result=0;
                else
                    result=length(electrodeManager.TestPulseElectrodes);
                end
            end
        end
        
        function result=get.AmplitudeAsDoublePerElectrode(self)
            % Get the amplitudes of the test pulse for all the
            % marked-for-test-pulsing electrodes, as a double array.            
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %resultAsCellArray={testPulseElectrodes.TestPulseAmplitude};
            resultAsCellArray=cellfun(@(electrode)(electrode.TestPulseAmplitude), ...
                                      testPulseElectrodes, ...
                                      'UniformOutput',false);
            result=cellfun(@(doubleString)(doubleString.toDouble()), ...
                           resultAsCellArray);
        end
        
        function value=get.Amplitude(self)
            if isempty(self.Electrode_)
                value=ws.utility.DoubleString('');
            else
                value=self.Electrode_.TestPulseAmplitude;
            end
        end
        
        function set.Amplitude(self,newString)  % in units of the electrode command channel
            if ~isempty(self.Electrode_) ,
                newValue=str2double(newString);
                if isfinite(newValue) ,
                    self.Electrode_.TestPulseAmplitude=newString;
                    %self.AmplitudeAsDouble_=newValue;
                    self.clearExistingSweepIfPresent();
                end
            end
            self.broadcast('Update');
        end
        
        function value=get.PulseDuration(self)  % s
            value=1e-3*str2double(self.PulseDurationInMsAsString_);  % ms->s
        end
        
        function value=get.PulseDurationInMsAsString(self)
            value=self.PulseDurationInMsAsString_;
        end
        
        function set.PulseDurationInMsAsString(self,newString)  % the duration of the pulse, in seconds.  The trial duration is twice this.
            newValue=str2double(newString);
            if ~isnan(newValue) && 5<=newValue && newValue<=500,
                self.PulseDurationInMsAsString_=strtrim(newString);
                self.clearExistingSweepIfPresent();
            end
            self.broadcast('Update');
        end

%         function command=get.Command(self)  % the command signal, in units geiven by the ChannelUnits property of the Stimulation object
%             t=self.Time;
%             delay=self.PulseDuration/2;
%             amplitude=self.Amplitude.toDouble();
%             command=amplitude*((delay<=t)&(t<delay+self.PulseDuration));
%             % command = ws.stimulus.SingleStimulus( ...
%             %               ws.stimulus.function.TestPulse('PulseDuration', self.PulseDuration, ...
%             %                                                 'PulseAmplitude', self.Amplitude ));                                                        
%         end                                                        

        function commands=get.CommandPerElectrode(self)  
            % Command signal for each test pulser electrode, each in units given by the ChannelUnits property 
            % of the Stimulation object
            t=self.Time;  % col vector
            delay=self.PulseDuration/2;
            amplitudes=self.AmplitudeAsDoublePerElectrode;  % row vector
            unscaledCommand=(delay<=t)&(t<delay+self.PulseDuration);  % col vector
            commands=bsxfun(@times,amplitudes,unscaledCommand);
        end  
        
%         function commandInVolts=get.CommandInVolts(self)  % the command signal, in volts to be sent out the AO channel
%             command=self.Command;
%             inverseChannelScale=1/self.CommandChannelScale;
%             commandInVolts=command*inverseChannelScale;
%         end
        
        function commandsInVolts=get.CommandInVoltsPerElectrode(self)  % the command signals, in volts to be sent out the AO channels
            import ws.utility.*
            commands=self.CommandPerElectrode;   % (nScans x nCommandChannels)
            commandChannelScales=self.CommandChannelScalePerElectrode;  % 1 x nCommandChannels
            inverseChannelScales=1./commandChannelScales;
            % zero any channels that have infinite (or nan) scale factor
            sanitizedInverseChannelScales=fif(isfinite(inverseChannelScales), inverseChannelScales, zeros(size(inverseChannelScales)));
            commandsInVolts=bsxfun(@times,commands,sanitizedInverseChannelScales);
        end                                                        

        function value=get.DoSubtractBaseline(self)
            value=self.DoSubtractBaseline_;
        end
        
        function set.DoSubtractBaseline(self,newValue)
            if islogical(newValue) ,
                self.DoSubtractBaseline_=newValue;
                self.clearExistingSweepIfPresent();
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
                    yLimits=self.AutomaticYLimits;
                    if ~isempty(yLimits) ,                    
                        self.YLimits_=yLimits;
                    end
                end
            end
            self.broadcast('Update');
        end
        
        function value=get.SamplingRate(self)
            value=self.SamplingRate_;
        end
        
        function set.SamplingRate(self,newValue)  % in Hz
            if isfinite(newValue) && newValue>0 ,
                self.SamplingRate_=newValue;
                self.clearExistingSweepIfPresent();                
            end
            self.broadcast('Update');
        end
        
        function value=get.Dt(self)  % s
            value=1/self.SamplingRate_;
        end
        
        function value=get.Time(self)  % s
            value=self.Dt*(0:(self.NScansInSweep-1))';  % s
        end
        
        function value=get.SweepDuration(self)  % s
            value=2*self.PulseDuration;
        end
        
        function value=get.NScansInSweep(self)
            sweepDuration=2*self.PulseDuration;
            value=round(sweepDuration/self.Dt);
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
            value=wavesurferModel.Stimulation.ChannelNames;
        end

        function value=get.MonitorChannelNames(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Acquisition.ChannelNames;
        end
        
        function value=get.IsRunning(self)
            value=self.IsRunning_;
        end

        function value=get.CommandUnits(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Stimulation.channelUnitsFromName(self.CommandChannelName);            
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
            stimulus=wavesurferModel.Stimulation;
            result=ws.utility.objectArray('ws.utility.SIUnit',[1 n]);
            for i=1:n ,
                unit=stimulus.channelUnitsFromName(commandChannelNames{i});
                if ~isempty(unit) ,
                    result(i)=unit;
                end
            end
        end  % function
        
        function value=get.MonitorUnits(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Acquisition.channelUnitsFromName(self.MonitorChannelName);           
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
            acquisition=wavesurferModel.Acquisition;
            result=ws.utility.objectArray('ws.utility.SIUnit',[1 n]);
            for i=1:n ,
                unit=acquisition.channelUnitsFromName(monitorChannelNames{i});
                if ~isempty(unit) ,
                    result(i)=unit;
                end
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
                if i==1 , 
                    volts=ws.utility.SIUnit('V');
                    amps=ws.utility.SIUnit('A');
                end
                result(i)=areSummable(commandUnitsPerElectrode(i),volts) && ...
                          areSummable(monitorUnitsPerElectrode(i),amps) ;
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
                if i==1 , 
                    volts=ws.utility.SIUnit('V');
                    amps=ws.utility.SIUnit('A');
                end
                result(i)=areSummable(commandUnitsPerElectrode(i),amps) && ...
                          areSummable(monitorUnitsPerElectrode(i),volts) ;
            end
        end  % function

        function value=get.IsVC(self)
            commandUnits=self.CommandUnits;
            monitorUnits=self.MonitorUnits;
            if isempty(commandUnits) || isempty(monitorUnits) ,
                value=false;
            else
                value=areSummable(commandUnits,ws.utility.SIUnit('V')) && ...
                      areSummable(monitorUnits,ws.utility.SIUnit('A')) ;
            end
        end  % function

        function value=get.IsCC(self)
            commandUnits=self.CommandUnits;
            monitorUnits=self.MonitorUnits;
            if isempty(commandUnits) || isempty(monitorUnits) ,
                value=false;
            else
                value=areSummable(commandUnits,ws.utility.SIUnit('A')) && ...
                      areSummable(monitorUnits,ws.utility.SIUnit('V')) ;
            end
        end

        function value=get.ResistanceUnits(self)
            if self.IsCC ,
                value=self.GainUnits;
            elseif self.IsVC , 
                value=1/self.GainUnits;                
            else
                value=ws.utility.SIUnit.empty();
            end
        end
        
%         function value=get.ResistanceUnitsPerElectrode(self)
%             value=self.GainUnitsPerElectrode;
%             value(self.IsVCPerElectrode)=1./value(self.IsVCPerElectrode);
%             % for elements that are not convertible to resistance, just
%             % leave as gain
%         end
        
        function value=get.GainUnits(self)
            if isempty(self.Electrode_)
                value=ws.utility.SIUnit.empty();                
            else
                value=(self.MonitorUnits/self.CommandUnits);
            end
        end
        
        function value=get.GainUnitsPerElectrode(self)
            value=(self.MonitorUnitsPerElectrode./self.CommandUnitsPerElectrode);
        end
        
        function value=get.GainOrResistanceUnits(self)
            if self.IsCC || self.IsVC ,
                value=self.ResistanceUnits;
            else
                value=self.GainUnits;
            end
        end
        
        function value=get.GainOrResistanceUnitsPerElectrode(self)
            value=self.GainUnitsPerElectrode;
            isVCPerElectrode=self.IsVCPerElectrode;
            value(isVCPerElectrode)=1./value(isVCPerElectrode);
            % for elements that are not convertible to resistance, just
            % leave as gain
        end
        
        function value=get.GainOrResistancePerElectrode(self)
            value=self.GainOrResistancePerElectrode_;
        end
        
        function value=get.UpdateRate(self)
            value=self.UpdateRate_;
        end
        
        function value=get.ElectrodeIndex(self)
            % the index of the current electrode in Electrodes (which is
            % just the test pulse electrodes)
            if isempty(self.Electrode_)
                value=zeros(1,0); 
            else
                isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
                iMatches=find(isElectrode);
                if isempty(iMatches) ,
                    % this should never happen...
                    value=zeros(1,0);
                else                    
                    value=iMatches(1);  
                end
            end
        end
        
        function value=get.Resistance(self)
            if isempty(self.Electrode_)
                value=zeros(1,0); 
            else
                %isElectrode=(self.Electrode_==self.Electrodes);
                isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
                value=self.ResistancePerElectrode_(isElectrode);
            end
        end
        
        function value=get.Gain(self)
            if isempty(self.Electrode_)
                value=zeros(1,0); 
            else
                %isElectrode=(self.Electrode_==self.Electrodes);
                isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
                value=self.GainPerElectrode_(isElectrode);
            end
        end
        
        function value=get.GainOrResistance(self)
            if self.IsVC || self.IsCC ,
                value=self.Resistance;
            else
                value=self.Gain;
            end
        end
        
        function value=get.Monitor(self)
            if isempty(self.Electrode_)
                value=nan(self.NScansInSweep,1); 
            else
                % isElectrode=(self.Electrode_==self.Electrodes);
                isElectrode=cellfun(@(electrode)(self.Electrode_==electrode),self.Electrodes);
                value=self.MonitorPerElectrode_(:,isElectrode);
            end
        end
        
        function value=get.InputDeviceNames(self)
            wavesurferModel=self.Parent_.Parent;            
            value=wavesurferModel.Acquisition.DeviceNames;
        end
        
        function value=get.OutputDeviceNames(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Stimulation.DeviceNames;
        end
        
        function result=get.CommandChannelIDPerElectrode(self)
            ephys=self.Parent_;
            electrodeManager=ephys.ElectrodeManager;
            testPulseElectrodes=electrodeManager.TestPulseElectrodes;
            %commandChannelNames={testPulseElectrodes.CommandChannelName};
            commandChannelNames=cellfun(@(electrode)(electrode.CommandChannelName), ...
                                        testPulseElectrodes, ...
                                        'UniformOutput',false);
            n=length(testPulseElectrodes);           
            wavesurferModel=ephys.Parent;
            stimulus=wavesurferModel.Stimulation;
            result=zeros(1,n);
            for i=1:n ,
                result(i)=stimulus.channelIDFromName(commandChannelNames{i});
            end
        end
        
        function result=get.MonitorChannelIDPerElectrode(self)
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
                result(i)=acquisition.channelIDFromName(monitorChannelNames{i});
            end
        end
        
        function value=get.MonitorChannelID(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Acquisition.channelIDFromName(self.MonitorChannelName);            
        end
        
        function value=get.MonitorChannelScale(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Acquisition.channelScaleFromName(self.MonitorChannelName);
        end
        
        function value=get.CommandChannelScale(self)
            wavesurferModel=self.Parent_.Parent;
            value=wavesurferModel.Stimulation.channelScaleFromName(self.CommandChannelName);
        end
        
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
            stimulus=wavesurferModel.Stimulation;
            result=zeros(1,n);
            for i=1:n ,
                result(i)=stimulus.channelScaleFromName(commandChannelNames{i});
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
            acquisition=wavesurferModel.Acquisition;
            result=zeros(1,n);
            for i=1:n ,
                result(i)=acquisition.channelScaleFromName(monitorChannelNames{i});
            end
        end
        
        function value=get.AreYLimitsForRunDetermined(self)
            value=self.AreYLimitsForRunDetermined_;
        end

        function yLimits=get.AutomaticYLimits(self)
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

        function value=get.ElectrodeMode(self)
            electrodeIndex=self.ElectrodeIndex;
            if isempty(electrodeIndex) ,
                value=[];
            else
                if isempty(self.Parent_)
                    value=[];
                else
                    ephys=self.Parent_;
                    if isempty(ephys) ,
                        value=[];
                    else
                        electrodeManager=ephys.ElectrodeManager;
                        if isempty(electrodeManager) ,
                            value=[];
                        else
                            value=electrodeManager.Electrodes{electrodeIndex}.Mode;
                        end
                    end
                end
            end
        end  % function        
        
        function set.ElectrodeMode(self,newValue)
            electrodeIndex=self.ElectrodeIndex;
            if isempty(electrodeIndex) ,
                return
            end
            ephys=[];
            electrodeManager=[];
            if ~isempty(self.Parent_)
                ephys=self.Parent_;
            end
            if ~isempty(ephys) ,
                electrodeManager=ephys.ElectrodeManager;
            end
            if ~isempty(electrodeManager) ,
                electrodeManager.setTestPulseElectrodeModeOrScaling(electrodeIndex,'Mode',newValue);
            end
        end  % function        
        
        function electrodeWasAdded(self,electrode)
            % Called by the parent Ephys when an electrode is added.
            
            % Redimension MonitorPerElectrode_ appropriately, etc.
            self.clearExistingSweepIfPresent()

            % If there's no current electrode, set Electrode to point to
            % the newly-created one.            
            if isempty(self.Electrode) ,
                self.Electrode=electrode;
            end
        end

        function electrodesRemoved(self)
            % Called by the parent Ephys when one or more electrodes are
            % removed.
            
            % Redimension MonitorPerElectrode_ appropriately, etc.
            self.clearExistingSweepIfPresent()
            
            % Change the electrode if needed
            self.changeElectrodeIfCurrentOneIsNotAvailable();
        end  % function
        
        function electrodeMayHaveChanged(self,electrode,propertyName) %#ok<INUSD>
            % Called by the parent Ephys to notify the TestPulser of a
            % change.
            if (self.Electrode == electrode) ,  % pointer comparison, essentially
                self.Electrode=electrode;  % call the setter to change everything that should change
            end
        end
        
        function isElectrodeMarkedForTestPulseMayHaveChanged(self)
            % Redimension MonitorPerElectrode_ appropriately, etc.
            self.clearExistingSweepIfPresent()
            
            % Change the electrode if needed
            self.changeElectrodeIfCurrentOneIsNotAvailable();
        end
        
        function start(self)
            % fprintf('Just entered start()...\n');
            if self.IsRunning ,
                % fprintf('About to exit start() via short-circuit...\n');                                            
                return
            end

            % Get some handles we'll need
            electrode=self.Electrode;
            ephys=self.Parent;
            electrodeManager=ephys.ElectrodeManager;
            wavesurferModel=[];
            if ~isempty(ephys) ,
                wavesurferModel=ephys.Parent;
            end                
            
            % Update the smart electrode channel scales, if possible and
            % needed
            if ~isempty(electrodeManager) ,
                electrodeManager.updateSmartElectrodeGainsAndModes();
            end
            
            % Check that we can start, and if not, return
            canStart= ...
                ~isempty(electrode) && ...
                electrodeManager.areAllElectrodesTestPulsable() && ...
                electrodeManager.areAllMonitorAndCommandChannelNamesDistinct() && ...
                (isempty(wavesurferModel) || wavesurferModel.State==ws.ApplicationState.Idle);
            if ~canStart,
                return
            end
            
%             % If present, notify the wavesurferModel that we're about to start
%             if ~isempty(wavesurferModel) ,
%                 wavesurferModel.willPerformTestPulse();
%             end
            
            % Get the stimulus
            commandsInVolts=self.CommandInVoltsPerElectrode;
            nScans=size(commandsInVolts,1);
            nElectrodes=size(commandsInVolts,2);

            % Set up the input task
            % fprintf('About to create the input task...\n');
            self.InputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Input');
            monitorChannelIDs=self.MonitorChannelIDPerElectrode;
            for i=1:nElectrodes
                self.InputTask_.createAIVoltageChan(self.InputDeviceNames{i},monitorChannelIDs(i));  % defaults to differential
            end
            clockString=sprintf('/%s/ao/SampleClock',self.OutputDeviceNames{1});  % Output device ID is something like 'Dev3'
            self.InputTask_.cfgSampClkTiming(self.SamplingRate,'DAQmx_Val_ContSamps',[],clockString);
              % set the sampling rate, and use the AO sample clock to keep
              % acquisiton synced with analog output

            % Set up the output task
            % fprintf('About to create the output task...\n');
            self.OutputTask_ = ws.dabs.ni.daqmx.Task('Test Pulse Output');
            commandChannelIDs=self.CommandChannelIDPerElectrode;
            for i=1:nElectrodes
                self.OutputTask_.createAOVoltageChan(self.OutputDeviceNames{i},commandChannelIDs(i));
            end
            self.OutputTask_.cfgSampClkTiming(self.SamplingRate,'DAQmx_Val_ContSamps',nScans);
            
            % Limit the stimulus to the allowable range
            limitedCommandsInVolts=max(-10,min(commandsInVolts,+10));
            
            % Write the command to the output task
            self.OutputTask_.writeAnalogData(limitedCommandsInVolts);

            % Set up the input task callback
            %nSamplesPerSweep=nScans*nElectrodes;
            self.InputTask_.everyNSamples=nScans;
            self.InputTask_.everyNSamplesEventCallbacks=@(varargin)(self.didPerformSweep());
            
            % Cache some things for speed during sweeps
            self.IsVCPerElectrodeCached_=self.IsVCPerElectrode;
            self.IsCCPerElectrodeCached_=self.IsCCPerElectrode;
            self.MonitorChannelInverseScalePerElectrodeCached_=1./self.MonitorChannelScalePerElectrode;
            %self.CommandChannelScalePerElectrodeCached_=self.CommandChannelScalePerElectrode;
            self.AmplitudeAsDoublePerElectrodeCached_=self.AmplitudeAsDoublePerElectrode;
            self.ElectrodeIndexCached_=self.ElectrodeIndex;
            self.NScansInSweepCached_ = self.NScansInSweep;
            self.NElectrodesCached_ = self.NElectrodes;
            
            % Compute some indices and cache them, again for speed during
            % sweeps
            totalDuration=self.SweepDuration;  % s
            t0Base=0; % s
            tfBase=1/8*totalDuration; % s
            t0Pulse=5/8*totalDuration; % s
            tfPulse=6/8*totalDuration; % s
            dt=self.Dt;
            self.I0BaseCached_ = floor(t0Base/dt)+1;
            self.IfBaseCached_ = floor(tfBase/dt);
            self.I0PulseCached_ = floor(t0Pulse/dt)+1;
            self.IfPulseCached_ = floor(tfPulse/dt);            

            % Finish up the start
            self.AreYLimitsForRunDetermined_=~self.IsAutoY_;  % if y is not auto, then the current y limits are kept
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
            
            % actually start the data acq tasks
            self.InputTask_.start();  % won't actually start until output starts b/c see above
            self.OutputTask_.start();
            
            % fprintf('About to exit start()...\n');
        end
        
        function stop(self)            
            %fprintf('Just entered stop()...\n');            
            if ~self.IsRunning ,
                %fprintf('About to exit stop() via short-circuit...\n');                            
                return
            end
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
            commandsInVolts=zeros(self.NScansInSweep,self.NElectrodes);
            self.OutputTask_.writeAnalogData(commandsInVolts);
            self.OutputTask_.start();
            % pause for 10 ms without relinquishing control
%             timerVal=tic();
%             while (toc(timerVal)<0.010)
%                 x=1+1; %#ok<NASGU>
%             end            
            ws.utility.sleep(0.010);  % pause for 10 ms
            self.OutputTask_.stop();
            % % Maybe try this: java.lang.Thread.sleep(10);
            
            % Continue with stopping stuff
            % fprintf('About to delete the tasks...\n');
            %self
            delete(self.InputTask_);
            delete(self.OutputTask_);
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
            
            % Notify subscribers
            %fprintf('Maybe about to broadcast MayHaveChanged.  doBroadcast: %d\n',doBroadcast);
%             if doBroadcast ,
%                 self.broadcast('Update');
%             end
            %self.IsStopping_=false;
            % fprintf('About to exit stop()...\n');                        
        end
        
        function set.IsRunning(self,newValue)
            if islogical(newValue) && isscalar(newValue),
                if self.IsRunning, 
                    if ~newValue ,
                        self.stop();
                    end
                else
                    if newValue ,
                        self.start();
                    end
                end
            end
        end
        
        function toggleIsRunning(self)
            if self.IsRunning ,
                self.stop();
            else
                self.start();
            end
        end
        
        function didPerformSweep(self,varargin)
            % compute resistance
            % compute delta in monitor
            % Specify the time windows for measuring the baseline and the pulse amplitude
            %fprintf('Inside TestPulser::didPerformTrial()\n');
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
            self.GainPerElectrode_=monitorDelta./self.AmplitudeAsDoublePerElectrodeCached_;
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
            self.MonitorCached_=self.MonitorPerElectrode_(:,self.ElectrodeIndexCached_);
            %end
            self.tryToDetermineYLimitsForRun();
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
            %fprintf('About to exit TestPulser::didPerformTrial()\n');            
        end  % function
        
%         function doppelganger=clone(self)
%             % Make a clone of the ElectrodeManager.  This is another
%             % ElectrodeManager with the same settings.
%             import ws.*
%             s=self.encodeSettings();
%             doppelganger=TestPulser();
%             doppelganger.restoreSettings(s);
%         end
%         
%         function s=encodeSettings(self)
%             % Return a structure representing the current object settings.
%             s=struct();
%             s.PulseDurationInMsAsString=self.PulseDurationInMsAsString;
%             s.DoSubtractBaseline=self.DoSubtractBaseline;
%             s.IsAutoY=self.IsAutoY;
%             s.ElectrodeName=self.ElectrodeName;            
%         end
%         
%         function restoreSettings(self, s)
%             % Note that this uses the high-level setters, so it will cause
%             % any subscribers to get (several) MayHaveChanged events.
%             self.PulseDurationInMsAsString=s.PulseDurationInMsAsString;
%             self.DoSubtractBaseline=s.DoSubtractBaseline;
%             self.IsAutoY=s.IsAutoY;
%             self.ElectrodeName=s.ElectrodeName;            
%         end

        function mimic(self, other)
            % Note that this uses the high-level setters, so it will cause
            % any subscribers to get (several) MayHaveChanged events.
            self.PulseDurationInMsAsString=other.PulseDurationInMsAsString;
            self.DoSubtractBaseline=other.DoSubtractBaseline;
            self.IsAutoY=other.IsAutoY;
            electrodeName=other.ElectrodeName;
            %keyboard
            self.ElectrodeName=electrodeName;
        end
        
%         function original=restoreSettingsAndReturnCopyOfOriginal(self, s)
%             original=self.clone();
%             self.restoreSettings(s);
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
                
    end  % methods
        
    methods (Access=protected)
        function clearExistingSweepIfPresent(self)
            self.MonitorPerElectrode_=nan(self.NScansInSweep,self.NElectrodes);
            self.GainPerElectrode_=nan(1,self.NElectrodes);
            self.GainOrResistancePerElectrode_=nan(1,self.NElectrodes);
            self.UpdateRate_=nan;
        end
        
        function tryToDetermineYLimitsForRun(self)
            % If running and the y limits for the run haven't been
            % determined, try to determine them.  Sets
            % AreYLimitsForRunDetermined_ and AutomaticYLimits_ if successful.
            if self.IsRunning && ~self.AreYLimitsForRunDetermined_ ,
                yLimits=self.AutomaticYLimits;
                if ~isempty(yLimits) ,
                    self.AreYLimitsForRunDetermined_=true;
                    self.YLimits_=yLimits;
                end
            end
        end  % function
        
        function autosetYLimits(self)
            % Syncs the Y limits to the monitor signal, if self is in the
            % right mode and the monitor signal is well-behaved.
            if self.IsYAuto_ ,
                automaticYLimits=self.AutomaticYLimits;
                if ~isempty(automaticYLimits) ,
                    self.YLimits_=automaticYLimits;
                end
            end
        end

        function changeElectrodeIfCurrentOneIsNotAvailable(self)
            % Checks that the Electrode_ is still a valid choice.  If not,
            % tries to find another one.  If that also fails, sets
            % Electrode_ to empty.  Also, if Electrode_ is empty but there
            % is at least one test pulse electrode, makes Electrode_ point
            % to the first test pulse electrode.
            electrodes=self.Parent.ElectrodeManager.TestPulseElectrodes;
            if isempty(electrodes)
                self.Electrode=[];
            else
                if isempty(self.Electrode) ,
                    self.Electrode=electrodes{1};  % no current electrode, but electrodes is nonempty, so make the first one current.
                else
                    % If we get here, self.Electrode is a scalar of class
                    % Electrode, and electrode is a nonempty cell array of
                    % scalars of class Electrode
                    isMatch=cellfun(@(electrode)(self.Electrode==electrode),electrodes);
                    if any(isMatch)
                        % nothing to do here---self.Electrode is a handle
                        % that points to a current test pulse electrode
                    else
                        % It seems the current electrode has been deleted, or is
                        % not marked as being available for test pulsing
                        self.Electrode=electrodes{1};
                    end
                end
            end 
        end  % function

    end  % protected methods block
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.TestPulser.propertyAttributes();        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = struct();
            
            s.Parent = struct('Classes', 'ws.system.Ephys', 'AllowEmpty', true);
        end  % function
    end  % class methods block

end  % classdef
