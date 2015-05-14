classdef Logging < ws.system.Subsystem
    % Logging  Subsystem that logs data to disk.
    
    properties (Dependent=true)
        FileLocation  % absolute path of data file directory
        FileBaseName  % prefix for data file name to which trial index will be appended
        DoIncludeDate
        DoIncludeSessionIndex
        SessionIndex
        NextTrialIndex  % the index of the next trial (one-based).  (This gets reset if you change the FileBaseName.)
        IsOKToOverwrite  % logical, whether it's OK to overwrite data files without warning
    end
    
    properties (Dependent=true, SetAccess=immutable)
        AugmentedBaseName
        NextTrialSetAbsoluteFileName
        CurrentTrialSetAbsoluteFileName  % If WS is idle, empty.  If acquiring, the current trial set file name
        %CurrentTrialIndex
    end

    properties (Access = protected, Transient = true)
        DateAsString_
    end
    
    properties (Access = protected)
        FileLocation_
        FileBaseName_
        DoIncludeDate_
        DoIncludeSessionIndex_
        SessionIndex_
        NextTrialIndex_
        IsOKToOverwrite_
    end
    
    % These are all properties that are only used when acquisition is
    % ongoing.  They are set in willPerformExperiment(), and are nulled in
    % didPerformExperiment() and didAbortExperiment()
    properties (Access = protected, Transient=true)
        CurrentTrialSetAbsoluteFileName_
        CurrentDatasetOffset_
            % during acquisition, the index of the next "scan" to be written (one-based)
            % "scan" is an NI-ism meaning all the samples acquired for a
            % single time stamp
        ExpectedTrialSize_  
            % if all the acquired data for one trial were put into an array, this
            % would be the size of that array.  
            % I.e. [nScans nActiveChannels]        
        WriteToTrialId_  % During the acquisition of a trial set, the current trial index being written to
        ChunkSize_
        FirstTrialIndex_  % index of the first trial in the ongoing trial set
        DidCreateCurrentDataFile_  % whether the data file for the current trial set has been created
        LastTrialIndexForWhichDatasetCreated_  
          % For the current file/trialset, the trial index of the most-recently dataset in the data file.
          % Empty if the no dataset has yet been created for the current file.
        DidWriteSomeDataForThisTrial_        
        %CurrentTrialIndex_
    end

    events
        UpdateDoIncludeSessionIndex
    end
    
    methods
        function self = Logging(parent)
            self.CanEnable=true;            
            self.Parent=parent;
            self.FileLocation_ = 'C:\Data';
            self.FileBaseName_ = 'untitled';
            self.DoIncludeDate_ = false ;
            self.DoIncludeSessionIndex_ = false ;
            self.SessionIndex_ = 1 ;
            self.NextTrialIndex_ = 1 ; % Number of trials acquired since value was reset + 1 (reset occurs automatically on FileBaseName change).
            %self.FirstTrialIndexInNextFile_ = 1 ; % Number of trials acquired since value was reset + 1 (reset occurs automatically on FileBaseName change).
            self.IsOKToOverwrite_ = false ;
            self.DateAsString_ = datestr(now(),'yyyy-mm-dd') ;  % Determine this now, don't want it to change in mid-experiment
        end
        
        function delete(self)
            self.Parent=[];
        end
        
        function set.FileLocation(self, newValue)
            if ws.utility.isASettableValue(newValue), 
                self.validatePropArg('FileLocation', newValue);
                if exist(newValue,'dir') ,
                    originalValue=self.FileLocation_;
                    self.FileLocation_ = newValue;
                    % If file name has changed, reset the trial index
                    originalFullName=fullfile(originalValue,self.FileBaseName);
                    newFullName=fullfile(newValue,self.FileBaseName);
                    if ~isequal(originalFullName,newFullName) ,
                        self.NextTrialIndex = 1;
                    end
                end
            end
            %self.broadcast('DidSetFileLocation');
            self.broadcast('Update');            
        end
        
        function result=get.FileLocation(self)
            result=self.FileLocation_;
        end
        
        function set.FileBaseName(self, newValue)
            %fprintf('Entered set.FileBaseName()\n');            
            if ws.utility.isASettableValue(newValue), 
                self.validatePropArg('FileBaseName', newValue);
                originalValue=self.FileBaseName_;
                self.FileBaseName_ = newValue;
                % If file name has changed, reset the trial index
                originalFullName=fullfile(self.FileLocation,originalValue);
                newFullName=fullfile(self.FileLocation,newValue);
                if ~isequal(originalFullName,newFullName) ,
                    %fprintf('About to reset NextTrialIndex...\n');
                    self.NextTrialIndex = 1;
                end
            end
            %self.broadcast('DidSetFileBaseName');            
            self.broadcast('Update');            
        end
        
        function result=get.FileBaseName(self)
            result=self.FileBaseName_;
        end
        
        function set.NextTrialIndex(self, newValue)
            %fprintf('set.NextTrialIndex\n');
            %dbstack
            if ws.utility.isASettableValue(newValue), 
                self.validatePropArg('NextTrialIndex', newValue);
                self.NextTrialIndex_ = newValue;
                %self.FirstTrialIndexInNextFile_ = newValue_ ;
            end
            %self.broadcast('DidSetNextTrialIndex');            
            self.broadcast('Update');            
        end
        
        function result=get.NextTrialIndex(self)
            result=self.NextTrialIndex_;
        end

%         function result=get.CurrentTrialIndex(self)
%             result=self.CurrentTrialIndex_;
%         end

        function set.IsOKToOverwrite(self, newValue)
            if ws.utility.isASettableValue(newValue), 
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && ~isnan(newValue))) ,
                    self.IsOKToOverwrite_ = logical(newValue);
                else
                    error('most:Model:invalidPropVal', ...
                          'IsOKToOverwrite must be a logical scalar, or convertable to one');                  
                end
            end
            self.broadcast('Update');                        
        end
        
        function result=get.IsOKToOverwrite(self)
            result=self.IsOKToOverwrite_;
        end
        
        function set.DoIncludeDate(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && ~isnan(newValue))) ,
                    self.DoIncludeDate_ = logical(newValue);
                else
                    error('most:Model:invalidPropVal', ...
                          'DoIncludeDate must be a logical scalar, or convertable to one');                  
                end
            end
            self.broadcast('Update');            
        end
        
        function result=get.DoIncludeDate(self)
            result=self.DoIncludeDate_;
        end

        function set.DoIncludeSessionIndex(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && ~isnan(newValue))) ,
                    originalValue = self.DoIncludeSessionIndex_ ;
                    newValueForReals = logical(newValue) ;
                    self.DoIncludeSessionIndex_ = newValueForReals ;
                    if newValueForReals && ~originalValue ,
                        self.NextTrialIndex_ = 1 ;
                        %self.FirstTrialIndexInNextFile_ = 1 ;
                    end
                else
                    error('most:Model:invalidPropVal', ...
                          'DoIncludeSessionIndex must be a logical scalar, or convertable to one');                  
                end
            end
            self.broadcast('UpdateDoIncludeSessionIndex');            
        end
        
        function result=get.DoIncludeSessionIndex(self)
            result=self.DoIncludeSessionIndex_;
        end

        function set.SessionIndex(self, newValue)
            if ws.utility.isASettableValue(newValue) ,
                if self.DoIncludeSessionIndex ,
                    if isnumeric(newValue) && isscalar(newValue) && round(newValue)==newValue && newValue>=1 ,
                        originalValue = self.SessionIndex_ ;
                        self.SessionIndex_ = newValue;
                        if newValue ~= originalValue ,
                            self.NextTrialIndex_ = 1 ;
                            %self.FirstTrialIndexInNextFile_ = 1 ;
                        end
                    else
                        error('most:Model:invalidPropVal', ...
                              'SessionIndex must be an integer greater than or equal to one');
                    end
                else
                    error('most:Model:invalidPropVal', ...
                          'Can''t set SessionIndex when DoIncludeSessionIndex is false');
                    
                end
            end
            self.broadcast('Update');
        end
        
        function result=get.SessionIndex(self)
            result=self.SessionIndex_;
        end
        
        function incrementSessionIndex(self)
            self.SessionIndex = self.SessionIndex + 1 ;
        end
        
        function result = get.AugmentedBaseName(self)
            result = self.augmentedBaseName_();
        end  % function
        
        function value=get.NextTrialSetAbsoluteFileName(self)
            wavesurferModel=self.Parent;
            firstTrialIndex = self.NextTrialIndex ;
            numberOfTrials = wavesurferModel.ExperimentTrialCount ;
            fileName = self.trialSetFileNameFromNumbers_(firstTrialIndex,numberOfTrials);
            value = fullfile(self.FileLocation, fileName);
        end  % function
        
        function value=get.CurrentTrialSetAbsoluteFileName(self)
            value = self.CurrentTrialSetAbsoluteFileName_ ;
        end  % function
        
        function willPerformExperiment(self, wavesurferModel, desiredApplicationState)
            if isempty(self.FileBaseName) ,
                error('wavesurfer:saveddatasystem:emptyfilename', 'Data logging can not be enabled with an empty filename.');
            end
            
            % Note that we have not yet created the current data file
            self.DidCreateCurrentDataFile_ = false ;
            
            % Set the chunk size for writing data to disk
            nActiveAnalogChannels = sum(wavesurferModel.Acquisition.IsAnalogChannelActive);
            switch desiredApplicationState ,
                case ws.ApplicationState.AcquiringTrialBased ,
                    self.ExpectedTrialSize_ = [wavesurferModel.Acquisition.ExpectedScanCount nActiveAnalogChannels];
                    if any(isinf(self.ExpectedTrialSize_))
                        self.ChunkSize_ = [wavesurferModel.Acquisition.SampleRate nActiveAnalogChannels];
                    else
                        self.ChunkSize_ = self.ExpectedTrialSize_;
                    end
%                     if wavesurferModel.ExperimentTrialCount == 1 ,
%                         trueLogFileName = sprintf('%s_%04d', self.FileBaseName, self.NextTrialIndex);
%                     else
%                         trueLogFileName = sprintf('%s_%04d-%04d', ...
%                                                   self.FileBaseName, ...
%                                                   self.NextTrialIndex, ...
%                                                   self.NextTrialIndex + wavesurferModel.ExperimentTrialCount - 1);
%                     end
                case ws.ApplicationState.AcquiringContinuously ,
                    self.ExpectedTrialSize_ = [Inf nActiveAnalogChannels];
                    self.ChunkSize_ = [wavesurferModel.Acquisition.SampleRate nActiveAnalogChannels];
%                     trueLogFileName = sprintf('%s-continuous_%s', self.FileBaseName, strrep(strrep(datestr(now), ' ', '_'), ':', '-'));
                otherwise
                    error('wavesurfer:saveddatasystem:invalidmode', ...
                          sprintf('%s is not a supported mode for data logging.', char(desiredApplicationState))); %#ok<SPERR>
            end
            
            % Determine the absolute file names
            %self.CurrentTrialSetAbsoluteFileName_ = fullfile(self.FileLocation, [trueLogFileName '.h5']);
            self.CurrentTrialSetAbsoluteFileName_ = self.NextTrialSetAbsoluteFileName ;
            %self.CurrentTrialIndex_ = self.NextTrialIndex ;
            
            % Store the first trial index for the trial set 
            self.FirstTrialIndex_ = self.NextTrialIndex ;
            
            % If the target dir doesn't exist, create it
            if ~exist(self.FileLocation, 'dir')
                mkdir(self.FileLocation);
            end
            
            % Check for filename collisions, if that's what user wants
            if self.IsOKToOverwrite ,
                % don't need to check anything
                % But need to delete pre-existing files, otherwise h5create
                % will just add datasets to a pre-existing file.
                if exist(self.CurrentTrialSetAbsoluteFileName_, 'file') == 2 ,
                    ws.utility.deleteFileWithoutWarning(self.CurrentTrialSetAbsoluteFileName_);
                end
%                 if exist(sidecarFileNameAbsolute, 'file') == 2 ,
%                     ws.utility.deleteFileWithoutWarning(sidecarFileNameAbsolute);
%                 end
            else
                % Check if the log file already exists, and error if so
                if exist(self.CurrentTrialSetAbsoluteFileName_, 'file') == 2 ,
                    error('wavesurfer:logFileAlreadyExists', ...
                          'The data file %s already exists', self.CurrentTrialSetAbsoluteFileName_);
                end
%                 if exist(sidecarFileNameAbsolute, 'file') == 2 ,
%                     error('wavesurfer:sidecarFileAlreadyExists', ...
%                           'The sidecar file %s already exists', self.CurrentTrialSetAbsoluteFileName_);
%                 end
            end

            % Extract all the "headerable" info in the WS model into a
            % structure
            headerStruct = wavesurferModel.encodeForFileType('header');
            
            % Put the header into into the log file header
            %numericPrecision=4;
            %stringOfAssignmentStatements= ws.most.util.structOrObj2Assignments(headerStruct, 'header', [], numericPrecision);
            doCreateFile=true;
            %ws.most.fileutil.h5savestr(self.CurrentTrialSetAbsoluteFileName_, '/headerstr', stringOfAssignmentStatements, doCreateFile);
            ws.most.fileutil.h5save(self.CurrentTrialSetAbsoluteFileName_, '/header', headerStruct, doCreateFile);
            self.DidCreateCurrentDataFile_ = true ;
            
%             % Save the "header" information to a sidecar file instead.
%             % This should be more flexible that embedding the "header" data
%             % in with the data sensu strictu.
%             save('-mat',sidecarFileNameAbsolute,'-struct','headerStruct');
            
            % Set the write-to trial ID so it's correct when data needs to
            % be written
            self.WriteToTrialId_ = self.NextTrialIndex;
            
            % Add an HDF "dataset" for each active AI channel, for each
            % trial.
            % TODO: Try moving the dataset creation for each trial to
            % willPerformTrial() --- This is the cause of slowness at trial
            % set start for Justin Little, possibly others.
%             if ~isempty(wavesurferModel.Acquisition) ,
%                 for indexOfTrialWithinSet = 1:wavesurferModel.ExperimentTrialCount ,
%                     h5create(self.CurrentTrialSetAbsoluteFileName_, ...
%                              sprintf('/trial_%04d', ...
%                                      self.WriteToTrialId_ + (indexOfTrialWithinSet-1)), ...
%                              self.ExpectedTrialSize_, ...
%                              'ChunkSize', chunkSize, ...
%                              'DataType','int16');
%                 end
%             end
            
            % The next incoming scan will be written to this (one-based)
            % index in the dataset
            self.CurrentDatasetOffset_ = 1;
            
            % This should be empty until we create a dataset for a trial
            self.LastTrialIndexForWhichDatasetCreated_ = [] ;
            
            % For tidyness
            self.DidWriteSomeDataForThisTrial_ = [] ;
        end
        
        function willPerformTrial(self, wavesurferModel) %#ok<INUSD>
            %profile resume
            thisTrialIndex = self.NextTrialIndex ;
            timestampDatasetName = sprintf('/trial_%04d/timestamp',thisTrialIndex) ;
            h5create(self.CurrentTrialSetAbsoluteFileName_, timestampDatasetName, [1 1]);  % will consist of one double
            scansDatasetName = sprintf('/trial_%04d/analogScans',thisTrialIndex) ;
            h5create(self.CurrentTrialSetAbsoluteFileName_, ...
                     scansDatasetName, ...
                     self.ExpectedTrialSize_, ...
                     'ChunkSize', self.ChunkSize_, ...
                     'DataType','int16');
            scansDatasetName = sprintf('/trial_%04d/digitalScans',thisTrialIndex) ;
            % TODO: Probably need to change to number of active digital channels
            % below
            NActiveDigitalChannels = sum(self.Parent.Acquisition.IsDigitalChannelActive);
            if NActiveDigitalChannels<=8
                dataType = 'uint8';
            elseif NActiveDigitalChannels<=16
                dataType = 'uint16';
            else %NActiveDigitalChannels<=32
                dataType = 'uint32';
            end
            if NActiveDigitalChannels>0 ,
                h5create(self.CurrentTrialSetAbsoluteFileName_, ...
                         scansDatasetName, ...
                         [self.ExpectedTrialSize_(1) 1], ...
                         'ChunkSize', [self.ChunkSize_(1) 1], ...
                         'DataType',dataType);
            end
            self.LastTrialIndexForWhichDatasetCreated_ =  thisTrialIndex;                     
            self.DidWriteSomeDataForThisTrial_ = false ;
            %profile off
        end
        
        function didPerformTrial(self, wavesurferModel) %#ok<INUSD>
            %if wavesurferModel.State == ws.ApplicationState.AcquiringTrialBased ,
                %self.CurrentTrialIndex_ = self.CurrentTrialIndex_ + 1 ;
                self.NextTrialIndex = self.NextTrialIndex + 1;
            %end
        end
        
        function didAbortTrial(self, wavesurferModel) %#ok<INUSD>
            %if wavesurferModel.State == ws.ApplicationState.AcquiringTrialBased ,
                if isempty(self.LastTrialIndexForWhichDatasetCreated_) ,
                    if isempty(self.FirstTrialIndex_) ,
                        % This probably means there was some sort of error
                        % before the trial even started.  So just leave
                        % NextTrialIndex alone.
                    else
                        % In this case, no datasets were created, so put the
                        % trial index to the FirstTrialIndex for the set
                        self.NextTrialIndex = self.FirstTrialIndex_ ;
                    end
                else
                    self.NextTrialIndex = self.LastTrialIndexForWhichDatasetCreated_ + 1;
                end
            %end
        end
        
        function didPerformExperiment(self, ~)
            self.didPerformOrAbortExperiment_();
        end
        
        function didAbortExperiment(self, wavesurferModel) %#ok<INUSD>
            %fprintf('Logging::didAbortExperiment()\n');
        
            %dbstop if caught
            %
            % Want to rename the data file to reflect the actual number of trials acquired
            %
            exception = [] ;
            if self.DidCreateCurrentDataFile_ ,
                % A data file was created.  Might need to rename it, or delete it.
                originalAbsoluteLogFileName = self.CurrentTrialSetAbsoluteFileName_ ;
                firstTrialIndex = self.FirstTrialIndex_ ;
                if isempty(self.LastTrialIndexForWhichDatasetCreated_) ,
                    % This means no trials were actually added to the log file.
                    numberOfPartialTrialsLogged = 0 ;
                else                    
                    numberOfPartialTrialsLogged = self.LastTrialIndexForWhichDatasetCreated_ - firstTrialIndex + 1 ;  % includes complete and partial trials
                end
                if numberOfPartialTrialsLogged == 0 ,
                    % If no trials logged, and we actually created the data file for the current trial set, delete the file
                    if self.DidCreateCurrentDataFile_ ,
                        ws.utility.deleteFileWithoutWarning(originalAbsoluteLogFileName);
                    else
                        % nothing to do
                    end
                else    
                    % We logged some trials, but maybe not the number number requested.  Check for this, renaming the
                    % data file if needed.
                    newLogFileName = self.trialSetFileNameFromNumbers_(firstTrialIndex,numberOfPartialTrialsLogged) ;
                    newAbsoluteLogFileName = fullfile(self.FileLocation, newLogFileName);
                    if isequal(originalAbsoluteLogFileName,newAbsoluteLogFileName) ,
                        % This might happen, e.g. if the number of trials is inf
                        % do nothing.
                    else
                        % Check for filename collisions, if that's what user wants
                        if exist(newAbsoluteLogFileName, 'file') == 2 ,
                            if self.IsOKToOverwrite ,
                                % don't need to check anything
                                % But need to delete pre-existing files, otherwise h5create
                                % will just add datasets to a pre-existing file.
                                ws.utility.deleteFileWithoutWarning(newAbsoluteLogFileName);
                            else
                                exception = MException('wavesurfer:unableToRenameLogFile', ...
                                                       'Unable to rename data file after abort, because file %s already exists', newLogFileName);
                            end
                        end
                        % If all is well here, rename the file
                        if isempty(exception) ,
                            movefile(originalAbsoluteLogFileName,newAbsoluteLogFileName);
                        end                
                    end
                end
            else
                % No data file was created, so nothing to do.
            end

            % Now do things common to performance and abortion
            self.didPerformOrAbortExperiment_();

            % Now throw that exception, if there was one
            %dbclear all
            if isempty(exception) ,                
                % do nothing
            else
                throw(exception);
            end            
         end  % function
            
    end
    
    methods (Access=protected)
%         function didPerformOrAbortTrial_(self, wavesurferModel)
%             if wavesurferModel.State == ws.ApplicationState.AcquiringTrialBased ,
%                 self.NextTrialIndex = self.NextTrialIndex + 1;
%             end
%         end
        
        function didPerformOrAbortExperiment_(self)
            % null-out all the transient things that are only used during
            % the trial set
            self.CurrentTrialSetAbsoluteFileName_ = [];
            self.FirstTrialIndex_ = [] ;
            self.CurrentDatasetOffset_ = [];
            self.ExpectedTrialSize_ = [];
            self.WriteToTrialId_ = [];
            self.ChunkSize_ = [];
            self.DidCreateCurrentDataFile_ = [] ;
            self.LastTrialIndexForWhichDatasetCreated_ = [] ;
            self.DidWriteSomeDataForThisTrial_ = [] ;
            %self.CurrentTrialIndex_ = [];
        end
    end

    methods
        function dataIsAvailable(self, state, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceExperimentStartAtStartOfData) %#ok<INUSL>
            %ticId=tic();
            
%             if self.Parent.State == ws.ApplicationState.TestPulsing || self.CurrentDatasetOffset_ < 1
%                 return
%             end
            
            %dataSingle=single(scaledData);
            %inputChannelNames=self.Parent.Acquisition.ActiveChannelNames;
            %nActiveChannels=self.Parent.Acquisition.NActiveChannels;
            if ~self.DidWriteSomeDataForThisTrial_ ,
                timestampDatasetName = sprintf('/trial_%04d/timestamp',self.WriteToTrialId_) ;
                h5write(self.CurrentTrialSetAbsoluteFileName_, timestampDatasetName, timeSinceExperimentStartAtStartOfData);
                self.DidWriteSomeDataForThisTrial_ = true ;  % will be true momentarily...
            end
            
            if ~isempty(self.FileBaseName) ,
                h5write(self.CurrentTrialSetAbsoluteFileName_, ...
                        sprintf('/trial_%04d/analogScans', ...
                                self.WriteToTrialId_), ...
                                rawAnalogData, ...
                                [self.CurrentDatasetOffset_ 1], ...
                                size(rawAnalogData));
                if ~isempty(rawDigitalData) ,
                    h5write(self.CurrentTrialSetAbsoluteFileName_, ...
                            sprintf('/trial_%04d/digitalScans', ...
                                    self.WriteToTrialId_), ...
                            rawDigitalData, ...
                            [self.CurrentDatasetOffset_ 1], ...
                            size(rawDigitalData));
                end
            end
            
            self.CurrentDatasetOffset_ = self.CurrentDatasetOffset_ + size(scaledAnalogData, 1);
            
            if self.CurrentDatasetOffset_ > self.ExpectedTrialSize_(1) ,
                self.CurrentDatasetOffset_ = 1;
                self.WriteToTrialId_ = self.WriteToTrialId_ + 1;
            end
            %T=toc(ticId);
            %fprintf('Time in Logging.dataAvailable(): %0.3f s\n',T);
        end
    end
    
    methods (Access = protected)
        function result = augmentedBaseName_(self)
            baseName = self.FileBaseName ;
            % Add the date, if wanted
            if self.DoIncludeDate_ ,
                baseNameWithDate = sprintf('%s_%s',baseName,self.DateAsString_);
            else
                baseNameWithDate = baseName ;
            end
            % Add the session number, if wanted
            if self.DoIncludeSessionIndex_ ,
                result = sprintf('%s_%03d',baseNameWithDate,self.SessionIndex_);
            else
                result = baseNameWithDate ;
            end
        end  % function        
        
        function fileName = trialSetFileNameFromNumbers_(self,firstTrialIndex,numberOfTrials)
            augmentedBaseName = self.augmentedBaseName_() ;
            % This is a "leaf" file name, not an absolute one
            if numberOfTrials == 1 ,
                fileName = sprintf('%s_%04d.h5', augmentedBaseName, firstTrialIndex);
            else
                if isfinite(numberOfTrials) ,
                    lastTrialIndex = firstTrialIndex + numberOfTrials - 1 ;
                    fileName = sprintf('%s_%04d-%04d.h5', ...
                                       augmentedBaseName, ...
                                       firstTrialIndex, ...
                                       lastTrialIndex);
                else
                    fileName = sprintf('%s_%04d-.h5', ...
                                       augmentedBaseName, ...
                                       firstTrialIndex);
                end
            end            
        end  % function        
    end  % static methods block
    
    methods (Access = protected)
        function defineDefaultPropertyAttributes(self)
            defineDefaultPropertyAttributes@ws.system.Subsystem(self);
            self.setPropertyAttributeFeatures('FileLocation', 'Classes', 'char', 'Attributes', {'vector'});
            self.setPropertyAttributeFeatures('FileBaseName', 'Classes', 'char', 'Attributes', {'vector'});
            self.setPropertyAttributeFeatures('NextTrialIndex', 'Attributes', {'scalar', 'finite', 'integer', '>=', 1});
        end
        
%         function defineDefaultPropertyTags(self)
%             defineDefaultPropertyTags@ws.system.Subsystem(self);            
%             % self.setPropertyTags('Enabled', 'ExcludeFromFileTypes', {'*'});  
%             %self.setPropertyTags('Enabled', 'IncludeInFileTypes', {'cfg'});
%             %self.setPropertyTags('Enabled', 'ExcludeFromFileTypes', {'usr'});            
%             self.setPropertyTags('FileLocation', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('FileBaseName', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('NextTrialIndex', 'IncludeInFileTypes', {'cfg'});
%         end
        
%         function zprvFileLocationWillChange(self, ~, ~)
%             self.CachedLoggingFileNameInfo_{1} = self.FileLocation;
%         end
%         
%         function zprvFileBaseNameWillChange(self, ~, ~)
%             self.CachedLoggingFileNameInfo_{2} = self.FileBaseName;
%         end
%         
%         function zprvFileLocationOrBaseNameDidChange(self, ~, ~)
%             % MATLAB loves to fire set events when the value does not actually change.
%             if ~strcmp(fullfile(self.CachedLoggingFileNameInfo_{1}, self.CachedLoggingFileNameInfo_{2}), fullfile(self.FileLocation, self.FileBaseName))
%                 self.NextTrialIndex = 1;
%             end
%         end
    end
    
%     methods (Access=public)
%         function resetProtocol(self)  % has to be public so WavesurferModel can call it
%             % Clears all aspects of the current protocol (i.e. the stuff
%             % that gets saved/loaded to/from the config file.  Idea here is
%             % to return the protocol properties stored in the model to a
%             % blank slate, so that we're sure no aspects of the old
%             % protocol get carried over when loading a new .cfg file.
%             
%             self.Enabled=true;
%             self.FileBaseName='untitled';
%             self.FileLocation='C:\Data';
%             self.NextTrialIndex=1;
%         end  % function
%     end % methods

    methods (Access=protected)        
        function out = getPropertyValue(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.mixin.Coding.
        function setPropertyValue(self, name, value)
            self.(name) = value;
        end  % function
    end
    
    properties (Hidden, SetAccess=protected)
        mdlPropAttributes = ws.system.Logging.propertyAttributes();
        
        mdlHeaderExcludeProps = {};
    end
    
    methods (Static)
        function s = propertyAttributes()
            s = ws.system.Subsystem.propertyAttributes();

            s.FileLocation = struct('Classes', 'string');
            s.FileBaseName = struct('Classes', 'string');
            s.NextTrialIndex = struct('Attributes', {{'scalar', 'finite', 'integer', '>=', 1}});
            s.IsOKToOverwrite = struct('Classes','binarylogical', 'Attributes', {{'scalar'}} );            
        end  % function
    end  % class methods block
    
    
end
