classdef LooperAcquisition < ws.system.AcquisitionSubsystem
    
    properties (Dependent=true)
        IsArmedOrAcquiring
            % This goes true during self.startingSweep() and goes false
            % after a single finite acquisition has completed.  Then the
            % cycle may repeat, depending...
    end
    
    properties (Access = protected, Transient=true)
        IsArmedOrAcquiring_ = false
            % This goes true during self.startingSweep() and goes false
            % after a single finite acquisition has completed.  Then the
            % cycle may repeat, depending...
        AreSweepsContinuous_
            % this is set to true or false at the start of a run, and is
            % used during polling to see if we need to check the DAQmx
            % tasks for doneness.  If sweeps are continuous, there's no
            % need to check.  This is an important optimization, b/c
            % checking takes 10-20 ms
        AnalogInputTask_ = []    % an ws.ni.AnalogInputTask, or empty
        DigitalInputTask_ = []    % an ws.ni.AnalogInputTask, or empty
        IsAtLeastOneActiveAnalogChannelCached_
        IsAtLeastOneActiveDigitalChannelCached_
    end    
    
    methods
        function self = LooperAcquisition(parent)
            self@ws.system.AcquisitionSubsystem(parent);
        end
        
        function delete(self)
            %fprintf('Acquisition::delete()\n');
            self.AnalogInputTask_=[];
            self.DigitalInputTask_=[];
        end
        
        function output = get.IsArmedOrAcquiring(self)
            output = self.IsArmedOrAcquiring_ ;
        end
        
        function acquireHardwareResources_(self)
            % We create and analog InputTask and a digital InputTask, regardless
            % of whether there are any channels of each type.  Within InputTask,
            % it will create a DABS Task only if the number of channels is
            % greater than zero.  But InputTask hides that detail from us.
            %keyboard
            if isempty(self.AnalogInputTask_) ,  % && self.NAnalogChannels>0 ,
                % Only hand the active channels to the AnalogInputTask
                isAnalogChannelActive = self.IsAnalogChannelActive ;
                %activeAnalogChannelNames = self.AnalogChannelNames(isAnalogChannelActive) ;
                %activeAnalogTerminalNames = self.AnalogTerminalNames(isAnalogChannelActive) ;
                activeAnalogDeviceNames = self.AnalogDeviceNames(isAnalogChannelActive) ;
                activeAnalogTerminalIDs = self.AnalogTerminalIDs(isAnalogChannelActive) ;
                self.AnalogInputTask_ = ...
                    ws.ni.InputTask(self, 'analog', ...
                                          'WaveSurfer Analog Acquisition Task', ...
                                          activeAnalogDeviceNames, ...
                                          activeAnalogTerminalIDs, ...
                                          self.SampleRate, ...
                                          self.Duration) ;
                % Set other things in the Task object
                %self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration ;
                %self.AnalogInputTask_.SampleRate = self.SampleRate;                
            end
            if isempty(self.DigitalInputTask_) , % && self.NDigitalChannels>0,
                isDigitalChannelActive = self.IsDigitalChannelActive ;
                %activeDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelActive) ;                
                %activeDigitalTerminalNames = self.DigitalTerminalNames(isDigitalChannelActive) ;                
                activeDigitalDeviceNames = self.DigitalDeviceNames(isDigitalChannelActive) ;
                activeDigitalTerminalIDs = self.DigitalTerminalIDs(isDigitalChannelActive) ;
                self.DigitalInputTask_ = ...
                    ws.ni.InputTask(self, 'digital', ...
                                          'WaveSurfer Digital Acquisition Task', ...
                                          activeDigitalDeviceNames, ...
                                          activeDigitalTerminalIDs, ...
                                          self.SampleRate, ...
                                          self.Duration) ;
                % Set other things in the Task object
                %self.DigitalInputTask_.DurationPerDataAvailableCallback = self.Duration ;
                %self.DigitalInputTask_.SampleRate = self.SampleRate;                
            end
        end  % function

        function releaseHardwareResources(self)
            self.AnalogInputTask_=[];            
            self.DigitalInputTask_=[];            
        end
        
        function startingRun(self)
            parent = self.Parent ;
            
            % Make the NI daq task, if don't have it already
            self.acquireHardwareResources_();

            % Set up the task triggering
            keystoneTask = parent.AcquisitionKeystoneTaskCache ;
            if isequal(keystoneTask,'ai') ,
                self.AnalogInputTask_.TriggerTerminalName = sprintf('PFI%d',self.TriggerScheme.PFIID) ;
                self.AnalogInputTask_.TriggerEdge = self.TriggerScheme.Edge ;
                self.DigitalInputTask_.TriggerTerminalName = 'ai/StartTrigger' ;
                self.DigitalInputTask_.TriggerEdge = 'rising' ;
            elseif isequal(keystoneTask,'di') ,
                self.AnalogInputTask_.TriggerTerminalName = 'di/StartTrigger' ;
                self.AnalogInputTask_.TriggerEdge = 'rising' ;                
                self.DigitalInputTask_.TriggerTerminalName = sprintf('PFI%d',self.TriggerScheme.PFIID) ;
                self.DigitalInputTask_.TriggerEdge = self.TriggerScheme.Edge ;
            else
                % Getting here means there was a programmer error
                error('ws:InternalError', ...
                      'Adam is a dum-dum, and the magic number is 92834797');
            end
            
            % Set for finite-duration vs. continous acquisition
            if parent.AreSweepsContinuous ,
                self.AreSweepsContinuous_ = true ;
                self.AnalogInputTask_.AcquisitionDuration = +inf ;
                self.DigitalInputTask_.AcquisitionDuration = +inf ;
                %self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
                %self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
            else
                self.AreSweepsContinuous_ = false ;
                %self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
                self.AnalogInputTask_.AcquisitionDuration = self.Duration ;
                %self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
                self.DigitalInputTask_.AcquisitionDuration = self.Duration ;
            end
            
%             % Set the duration between data available callbacks
%             displayDuration = 1/wavesurferModel.Display.UpdateRate;
%             if self.Duration < displayDuration ,
%                 self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
%             else
%                 numIncrements = floor(self.Duration/displayDuration);
%                 assert(floor(self.Duration/numIncrements * self.AnalogInputTask_.SampleRate) == ...
%                        self.Duration/numIncrements * self.AnalogInputTask_.SampleRate, ...
%                        'The Display UpdateRate must result in an integer number of samples at the given sample rate and acquisition length.');
%                 self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration/numIncrements;
%             end
            
            % Dimension the cache that will hold acquired data in main
            % memory
            if self.NDigitalChannels<=8
                dataType = 'uint8';
            elseif self.NDigitalChannels<=16
                dataType = 'uint16';
            else %self.NDigitalChannels<=32
                dataType = 'uint32';
            end
            NActiveAnalogChannels = sum(self.IsAnalogChannelActive);
            NActiveDigitalChannels = sum(self.IsDigitalChannelActive);
            if parent.AreSweepsContinuous ,
                nScans = round(self.DataCacheDurationWhenContinuous_ * self.SampleRate) ;
                self.RawAnalogDataCache_ = zeros(nScans,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(nScans,min(1,NActiveDigitalChannels),dataType);
            elseif parent.AreSweepsFiniteDuration ,
                self.RawAnalogDataCache_ = zeros(self.ExpectedScanCount,NActiveAnalogChannels,'int16');
                self.RawDigitalDataCache_ = zeros(self.ExpectedScanCount,min(1,NActiveDigitalChannels),dataType);
            else
                % Shouldn't ever happen
                self.RawAnalogDataCache_ = [];                
                self.RawDigitalDataCache_ = [];                
            end
            
            self.IsAtLeastOneActiveAnalogChannelCached_ = (NActiveAnalogChannels>0) ;
            self.IsAtLeastOneActiveDigitalChannelCached_ = (NActiveDigitalChannels>0) ;
            
            % Arm the AI task
            self.AnalogInputTask_.arm();
            self.DigitalInputTask_.arm();
        end  % function
        
        function completingRun(self)
            %fprintf('Acquisition::completingRun()\n');
            self.completingOrStoppingOrAbortingRun_();
        end  % function
        
        function stoppingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end  % function

        function abortingRun(self)
            self.completingOrStoppingOrAbortingRun_();
        end  % function

        function startingSweep(self)
            %fprintf('LooperAcquisition::startingSweep()\n');
            self.IsArmedOrAcquiring_ = true;
            self.NScansFromLatestCallback_ = [] ;
            self.IndexOfLastScanInCache_ = 0 ;
            self.IsAllDataInCacheValid_ = false ;
            self.TimeOfLastPollingTimerFire_ = 0 ;  % not really true, but works
            self.NScansReadThisSweep_ = 0 ;
            self.DigitalInputTask_.start();
            self.AnalogInputTask_.start();
        end  % function
        
        function completingSweep(self) %#ok<MANU>
            %fprintf('Acquisition::completingSweep()\n');
        end
        
        function stoppingSweep(self)
            self.AnalogInputTask_.stop();
            self.DigitalInputTask_.stop();
            self.IsArmedOrAcquiring_ = false ;
        end  % function

        function abortingSweep(self)
            try
                self.AnalogInputTask_.stop();  
                    % this is correct, we stop() the task, even though we're aborting the sweep.  
                    % stop and abort mean
                    % different things when
                    % we're talking about sweeps versus tasks
                self.DigitalInputTask_.stop();
            catch me %#ok<NASGU>
                % abortingSweep() cannot throw an error, so we ignore any
                % errors that arise here.
            end
            self.IsArmedOrAcquiring_ = false;
        end  % function
                        
        function samplesAcquired(self, isSweepBased, t, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD,INUSL>
            % Called by the Looper when data is available.  When called, we update
            % our main-memory data cache with the newly available data.
            %fprintf('\n\n');
            %fprintf('LooperAcquisition::samplesAcquired:\n');
            %dbstack
            %fprintf('\n\n');
            self.addDataToUserCache(rawAnalogData, rawDigitalData, isSweepBased) ;
        end  % function
        
    end  % methods block
    
    methods (Access = protected)
        function completingOrStoppingOrAbortingRun_(self)
            if ~isempty(self.AnalogInputTask_) ,
                if isvalid(self.AnalogInputTask_) ,
                    self.AnalogInputTask_.disarm();
                else
                    self.AnalogInputTask_ = [] ;
                end
            end
            if ~isempty(self.DigitalInputTask_) ,
                if isvalid(self.DigitalInputTask_) ,
                    self.DigitalInputTask_.disarm();
                else
                    self.DigitalInputTask_ = [] ;
                end                    
            end
            self.IsArmedOrAcquiring_ = false;            
        end  % function
        
%         function acquisitionSweepComplete_(self)
%             fprintf('LooperAcquisition::acquisitionSweepComplete_()\n');
%             self.IsArmedOrAcquiring_ = false ;
%             parent = self.Parent ;
%             if ~isempty(parent) && isvalid(parent) ,
%                 parent.acquisitionSweepComplete() ;
%             end
%         end  % function
        
%         function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
%             parent=self.Parent;
%             if ~isempty(parent) && isvalid(parent) ,
%                 parent.samplesAcquired(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData);
%             end
%         end  % function

        function [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                readDataFromTasks_(self, timeSinceSweepStart, fromRunStartTicId, areTasksDone) %#ok<INUSD>
            % both analog and digital tasks are for-real
            if self.IsAtLeastOneActiveAnalogChannelCached_ ,
                [rawAnalogData,timeSinceRunStartAtStartOfData] = ...
                    self.AnalogInputTask_.readData([], timeSinceSweepStart, fromRunStartTicId);
                nScans = size(rawAnalogData,1) ;
                rawDigitalData = ...
                    self.DigitalInputTask_.readData(nScans, timeSinceSweepStart, fromRunStartTicId);
            elseif self.IsAtLeastOneActiveDigitalChannelCached_ ,
                % There are zero active analog channels, but at least one
                % active digital channel.
                % In this case, want the digital task to determine the
                % "pace" of data acquisition.
                [rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                    self.DigitalInputTask_.readData([], timeSinceSweepStart, fromRunStartTicId);                    
                nScans = size(rawDigitalData,1) ;
                rawAnalogData = zeros(nScans, 0, 'int16') ;
                % rawAnalogData  = ...
                %     self.AnalogInputTask_.readData(nScans, timeSinceSweepStart, fromRunStartTicId);
            else
                % If we get here, we've made a programming error --- this
                % should have been caught when the run was started.
                error('wavesurfer:ZeroActiveInputChannelsWhileReadingDataFromTasks', ...
                      'Internal error: No active input channels while reading data from tasks') ;
            end
            self.NScansReadThisSweep_ = self.NScansReadThisSweep_ + nScans ;
        end  % function
        
    end  % protected methods block
    
    methods
        function [didReadFromTasks,rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData,areTasksDone] = ...
                poll(self, timeSinceSweepStart, fromRunStartTicId)
            %fprintf('LooperAcquisition::poll()\n') ;
            % Determine the time since the last undropped timer fire
            timeSinceLastPollingTimerFire = timeSinceSweepStart - self.TimeOfLastPollingTimerFire_ ;  %#ok<NASGU>

            % Call the task to do the real work
            if self.IsArmedOrAcquiring_ ,
                %fprintf('LooperAcquisition::poll(): In self.IsArmedOrAcquiring_==true branch\n') ;
                % Check for task doneness
                if self.AreSweepsContinuous_ ,  
                    % if doing continuous acq, no need to check.  This is
                    % an important optimization, b/c the checks can take
                    % 10-20 ms.
                    areTasksDone = false;
                else                    
                    areTasksDone = ( self.AnalogInputTask_.isTaskDone() && self.DigitalInputTask_.isTaskDone() ) ;
                end
%                 if areTasksDone ,
%                     fprintf('Acquisition tasks are done.\n')
%                 end
                
                % Get data
                %if areTasksDone ,
                %    fprintf('About to readDataFromTasks_, even though acquisition tasks are done.\n')
                %end
                [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                    self.readDataFromTasks_(timeSinceSweepStart, fromRunStartTicId, areTasksDone) ;
                %nScans = size(rawAnalogData,1) ;
                %fprintf('Read acq data. nScans: %d\n',nScans)

                % Notify the whole system that samples were acquired
                didReadFromTasks = true ;  % we return this, even if zero samples were acquired
                %self.samplesAcquired_(rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData);

                % If we were done before reading the data, act accordingly
                if areTasksDone ,
                    % Stop tasks, set flag to reflect that we're no longer
                    % armed nor acquiring
                    self.AnalogInputTask_.stop();
                    self.DigitalInputTask_.stop();
                    self.IsArmedOrAcquiring_ = false ;
                end
            else
                %fprintf('~IsArmedOrAcquiring\n') ;
                didReadFromTasks = false ;
                rawAnalogData = [] ;
                rawDigitalData = [] ;
                timeSinceRunStartAtStartOfData = false ;
                areTasksDone = [] ;  
            end
            
            % Prepare for next time            
            self.TimeOfLastPollingTimerFire_ = timeSinceSweepStart ;
        end        
        
        function didSetDeviceNameInFrontend(self)
            deviceName = self.Parent.DeviceName ;
            self.AnalogDeviceNames_(:) = {deviceName} ;
            self.DigitalDeviceNames_(:) = {deviceName} ;            
            %self.broadcast('Update');
        end        
        
        function mimickingWavesurferModel_(self)
            deviceName = self.Parent.DeviceName ;
            self.AnalogDeviceNames_(:) = {deviceName} ;
            self.DigitalDeviceNames_(:) = {deviceName} ;            
            %self.broadcast('Update');
        end        
    end  % public methods block
    
end  % classdef
