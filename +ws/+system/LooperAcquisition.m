classdef LooperAcquisition < ws.system.AcquisitionSubsystem
    
    properties (Dependent=true)
        IsArmedOrAcquiring
            % This goes true during self.willPerformSweep() and goes false
            % after a single finite acquisition has completed.  Then the
            % cycle may repeat, depending...
    end
    
    properties (Access = protected, Transient=true)
        IsArmedOrAcquiring_ = false
            % This goes true during self.willPerformSweep() and goes false
            % after a single finite acquisition has completed.  Then the
            % cycle may repeat, depending...
        AnalogInputTask_ = []    % an ws.ni.AnalogInputTask, or empty
        DigitalInputTask_ = []    % an ws.ni.AnalogInputTask, or empty
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
        
        function setCoreSettingsToMatchPackagedOnes(self,settings)
            for i=1:length(self.CoreFieldNames_)
                fieldName = self.CoreFieldNames_{i} ;
                self.(fieldName) = settings.(fieldName) ;
            end
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
                activeAnalogChannelNames = self.AnalogChannelNames(isAnalogChannelActive) ;                
                activeAnalogPhysicalChannelNames = self.AnalogPhysicalChannelNames(isAnalogChannelActive) ;                
                self.AnalogInputTask_ = ...
                    ws.ni.InputTask(self, 'analog', ...
                                          'Wavesurfer Analog Acquisition Task', ...
                                          activeAnalogPhysicalChannelNames, ...
                                          activeAnalogChannelNames);
                % Set other things in the Task object
                self.AnalogInputTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.AnalogInputTask_.SampleRate = self.SampleRate;                
                %self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionSweepComplete_);
                %self.AnalogInputTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
            if isempty(self.DigitalInputTask_) , % && self.NDigitalChannels>0,
                isDigitalChannelActive = self.IsDigitalChannelActive ;
                activeDigitalChannelNames = self.DigitalChannelNames(isDigitalChannelActive) ;                
                activeDigitalPhysicalChannelNames = self.DigitalPhysicalChannelNames(isDigitalChannelActive) ;                
                self.DigitalInputTask_ = ...
                    ws.ni.InputTask(self, 'digital', ...
                                          'Wavesurfer Digital Acquisition Task', ...
                                          activeDigitalPhysicalChannelNames, ...
                                          activeDigitalChannelNames);
                % Set other things in the Task object
                self.DigitalInputTask_.DurationPerDataAvailableCallback = self.Duration_;
                self.DigitalInputTask_.SampleRate = self.SampleRate;                
                %self.AnalogInputTask_.addlistener('AcquisitionComplete', @self.acquisitionSweepComplete_);
                %self.AnalogInputTask_.addlistener('SamplesAvailable', @self.samplesAcquired_);
            end
        end  % function

        function releaseHardwareResources(self)
            self.AnalogInputTask_=[];            
            self.DigitalInputTask_=[];            
        end
        
        function willPerformRun(self)
            parent = self.Parent ;
            
            % Make the NI daq task, if don't have it already
            self.acquireHardwareResources_();

            % Set up the task triggering
            self.AnalogInputTask_.TriggerPFIID = self.TriggerScheme.PFIID;
            self.AnalogInputTask_.TriggerEdge = self.TriggerScheme.Edge;
            self.DigitalInputTask_.TriggerPFIID = self.TriggerScheme.PFIID;
            self.DigitalInputTask_.TriggerEdge = self.TriggerScheme.Edge;
            
            % Set for finite-duration vs. continous acquisition
            if parent.AreSweepsContinuous ,
                self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
                self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_ContSamps';
            else
                self.AnalogInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
                self.AnalogInputTask_.AcquisitionDuration = self.Duration ;
                self.DigitalInputTask_.ClockTiming = 'DAQmx_Val_FiniteSamps';
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
            
            % Arm the AI task
            self.AnalogInputTask_.arm();
            self.DigitalInputTask_.arm();
        end  % function
        
        function didCompleteRun(self)
            %fprintf('Acquisition::didCompleteRun()\n');
            self.didPerformOrAbortRun_();
        end  % function
        
        function didAbortRun(self)
            self.didPerformOrAbortRun_();
        end  % function

        function willPerformSweep(self)
            %fprintf('Acquisition::willPerformSweep()\n');
            self.IsArmedOrAcquiring_ = true;
            self.NScansFromLatestCallback_ = [] ;
            self.IndexOfLastScanInCache_ = 0 ;
            self.IsAllDataInCacheValid_ = false ;
            self.TimeOfLastPollingTimerFire_ = 0 ;  % not really true, but works
            self.NScansReadThisSweep_ = 0 ;
            self.AnalogInputTask_.start();
            self.DigitalInputTask_.start();
        end  % function
        
        function didCompleteSweep(self) %#ok<MANU>
            %fprintf('Acquisition::didCompleteSweep()\n');
        end
        
        function didAbortSweep(self)
            try
                self.AnalogInputTask_.abort();
                self.DigitalInputTask_.abort();
            catch me %#ok<NASGU>
                % didAbortSweep() cannot throw an error, so we ignore any
                % errors that arise here.
            end
            self.IsArmedOrAcquiring_ = false;
        end  % function
                        
        function dataIsAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSD,INUSL>
            % Called "from above" when data is available.  When called, we update
            % our main-memory data cache with the newly available data.
            self.LatestAnalogData_ = scaledAnalogData ;
            self.LatestRawAnalogData_ = rawAnalogData ;
            self.LatestRawDigitalData_ = rawDigitalData ;
            if isSweepBased ,
                % add data to cache
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawAnalogData,1);
                jf=j0+n-1;
                self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                self.IndexOfLastScanInCache_ = jf ;
                self.NScansFromLatestCallback_ = n ;                
                if jf == size(self.RawAnalogDataCache_,1) ,
                     self.IsAllDataInCacheValid_ = true;
                end
            else                
                % Add data to cache, wrapping around if needed
                j0=self.IndexOfLastScanInCache_ + 1;
                n=size(rawAnalogData,1);
                jf=j0+n-1;
                nScansInCache = size(self.RawAnalogDataCache_,1);
                if jf<=nScansInCache ,
                    % the usual case
                    self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                    self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                    self.IndexOfLastScanInCache_ = jf ;
                elseif jf==nScansInCache ,
                    % the cache is just large enough to accommodate rawData
                    self.RawAnalogDataCache_(j0:jf,:) = rawAnalogData;
                    self.RawDigitalDataCache_(j0:jf,:) = rawDigitalData;
                    self.IndexOfLastScanInCache_ = 0 ;
                    self.IsAllDataInCacheValid_ = true ;
                else
                    % Need to write part of rawData to end of data cache,
                    % part to start of data cache                    
                    nScansAtStartOfCache = jf - nScansInCache ;
                    nScansAtEndOfCache = n - nScansAtStartOfCache ;
                    self.RawAnalogDataCache_(j0:end,:) = rawAnalogData(1:nScansAtEndOfCache,:) ;
                    self.RawAnalogDataCache_(1:nScansAtStartOfCache,:) = rawAnalogData(end-nScansAtStartOfCache+1:end,:) ;
                    self.RawDigitalDataCache_(j0:end,:) = rawDigitalData(1:nScansAtEndOfCache,:) ;
                    self.RawDigitalDataCache_(1:nScansAtStartOfCache,:) = rawDigitalData(end-nScansAtStartOfCache+1:end,:) ;
                    self.IsAllDataInCacheValid_ = true ;
                    self.IndexOfLastScanInCache_ = nScansAtStartOfCache ;
                end
                self.NScansFromLatestCallback_ = n ;
            end
        end  % function
        
    end  % methods block
    
    methods (Access = protected)
        function didPerformOrAbortRun_(self)
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
        
        function acquisitionSweepComplete_(self)
            fprintf('LooperAcquisition::acquisitionSweepComplete_()\n');
            self.IsArmedOrAcquiring_ = false ;
            parent = self.Parent ;
            if ~isempty(parent) && isvalid(parent) ,
                parent.acquisitionSweepComplete() ;
            end
        end  % function
        
        function samplesAcquired_(self, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData)
            parent=self.Parent;
            if ~isempty(parent) && isvalid(parent) ,
                parent.samplesAcquired(rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData);
            end
        end  % function

        function [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                readDataFromTasks_(self, timeSinceSweepStart, fromRunStartTicId, areTasksDone) %#ok<INUSD>
            % both analog and digital tasks are for-real
            [rawAnalogData,timeSinceRunStartAtStartOfData] = self.AnalogInputTask_.readData([], timeSinceSweepStart, fromRunStartTicId);
            nScans = size(rawAnalogData,1) ;
            %if areTasksDone ,
            %    fprintf('Tasks are done, and about to attampt to read %d scans from the digital input task.\n',nScans);
            %end
            rawDigitalData = ...
                self.DigitalInputTask_.readData(nScans, timeSinceSweepStart, fromRunStartTicId);
            self.NScansReadThisSweep_ = self.NScansReadThisSweep_ + nScans ;
        end  % function
        
    end  % protected methods block
                
    methods
        function poll(self, timeSinceSweepStart, fromRunStartTicId)
            fprintf('LooperAcquisition::poll()\n') ;
            % Determine the time since the last undropped timer fire
            timeSinceLastPollingTimerFire = timeSinceSweepStart - self.TimeOfLastPollingTimerFire_ ;  %#ok<NASGU>

            % Call the task to do the real work
            if self.IsArmedOrAcquiring ,
                fprintf('IsArmedOrAcquiring\n') ;
                % Check for task doneness
                areTasksDone = ( self.AnalogInputTask_.isTaskDone() && self.DigitalInputTask_.isTaskDone() ) ;
                if areTasksDone ,
                    fprintf('Acquisition tasks are done.\n')
                end
                
                % Get data
                %if areTasksDone ,
                %    fprintf('About to readDataFromTasks_, even though acquisition tasks are done.\n')
                %end
                [rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData] = ...
                    self.readDataFromTasks_(timeSinceSweepStart, fromRunStartTicId, areTasksDone) ;
                nScans = size(rawAnalogData,1) ;
                fprintf('Read acq data. nScans: %d\n',nScans)

                % Notify the whole system that samples were acquired
                self.samplesAcquired_(rawAnalogData,rawDigitalData,timeSinceRunStartAtStartOfData);

                % If we were done before reading the data, act accordingly
                if areTasksDone ,
                    %fprintf('Total number of scans read for this acquire: %d\n',self.NScansReadThisSweep_);
                
                    % Stop tasks, notify rest of system
                    self.AnalogInputTask_.stop();
                    self.DigitalInputTask_.stop();
                    self.acquisitionSweepComplete_();
                end
            else
                fprintf('~IsArmedOrAcquiring\n') ;
            end
            
            % Prepare for next time            
            self.TimeOfLastPollingTimerFire_ = timeSinceSweepStart ;
        end        
    end
    
end  % classdef
