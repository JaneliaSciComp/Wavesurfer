classdef Logging < ws.Subsystem
    % Logging  Subsystem that logs data to disk.
    
    properties (Dependent=true)
        FileLocation  % absolute path of data file directory
        FileBaseName  % prefix for data file name to which sweep index will be appended
        DoIncludeDate
        DoIncludeSessionIndex
        SessionIndex
        NextSweepIndex  % the index of the next sweep (one-based).  (This gets reset if you change the FileBaseName.)
        IsOKToOverwrite  % logical, whether it's OK to overwrite data files without warning
    end
    
    properties (Dependent=true, SetAccess=immutable)
        AugmentedBaseName
        NextRunAbsoluteFileName
        CurrentRunAbsoluteFileName  % If WS is idle, empty.  If acquiring, the current run file name
        %CurrentSweepIndex
    end

    properties (Access = protected)
        FileLocation_
        FileBaseName_
        DoIncludeDate_
        DoIncludeSessionIndex_
        SessionIndex_
        NextSweepIndex_
        IsOKToOverwrite_
    end

    properties (Access = protected, Transient = true)
        DateAsString_
    end

    % These are all properties that are only used when acquisition is
    % ongoing.  They are set in startingRun(), and are nulled in
    % completingRun() and abortingRun()
    properties (Access = protected, Transient=true)
        CurrentRunAbsoluteFileName_
        CurrentDatasetOffset_
            % during acquisition, the index of the next "scan" to be written (one-based)
            % "scan" is an NI-ism meaning all the samples acquired for a
            % single time stamp
        ExpectedSweepSizeForWritingHDF5_
        WriteToSweepId_  % During the acquisition of a run, the current sweep index being written to
        ChunkSize_
        FirstSweepIndex_  % index of the first sweep in the ongoing run
        DidCreateCurrentDataFile_  % whether the data file for the current run has been created
        LastSweepIndexForWhichDatasetCreated_  
          % For the current file/sweepset, the sweep index of the most-recently dataset in the data file.
          % Empty if the no dataset has yet been created for the current file.
        DidWriteSomeDataForThisSweep_        
        %CurrentSweepIndex_
    end

    events
        UpdateDoIncludeSessionIndex
    end
    
    methods
        function self = Logging(parent)
            self@ws.Subsystem(parent) ;
            self.FileLocation_ = 'C:\Data';
            self.FileBaseName_ = 'untitled';
            self.DoIncludeDate_ = false ;
            self.DoIncludeSessionIndex_ = false ;
            self.SessionIndex_ = 1 ;
            self.NextSweepIndex_ = 1 ; % Number of sweeps acquired since value was reset + 1 (reset occurs automatically on FileBaseName change).
            %self.FirstSweepIndexInNextFile_ = 1 ; % Number of sweeps acquired since value was reset + 1 (reset occurs automatically on FileBaseName change).
            self.IsOKToOverwrite_ = false ;
            self.DateAsString_ = datestr(now(),'yyyy-mm-dd') ;  % Determine this now, don't want it to change in mid-run
        end
        
        function set.FileLocation(self, newValue)
            if ws.isASettableValue(newValue) ,
                if ws.isString(newValue) ,
                    if exist(newValue,'dir') ,
                        originalValue=self.FileLocation_;
                        self.FileLocation_ = newValue;
                        % If file name has changed, reset the sweep index
                        originalFullName=fullfile(originalValue,self.FileBaseName);
                        newFullName=fullfile(newValue,self.FileBaseName);
                        if ~isequal(originalFullName,newFullName) ,
                            self.NextSweepIndex = 1;
                        end
                    end
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'FileLocation must be a string');                    
                end
            end
            self.broadcast('Update');            
        end
        
        function result=get.FileLocation(self)
            result=self.FileLocation_;
        end
        
        function set.FileBaseName(self, newValue)
            %fprintf('Entered set.FileBaseName()\n');            
            if ws.isASettableValue(newValue), 
                if ws.isString(newValue) ,
                    originalValue=self.FileBaseName_;
                    self.FileBaseName_ = newValue;
                    % If file name has changed, reset the sweep index
                    originalFullName=fullfile(self.FileLocation,originalValue);
                    newFullName=fullfile(self.FileLocation,newValue);
                    if ~isequal(originalFullName,newFullName) ,
                        %fprintf('About to reset NextSweepIndex...\n');
                        self.NextSweepIndex = 1;
                    end
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'FileBaseName must be a string');                    
                end
            end
            self.broadcast('Update');            
        end
        
        function result=get.FileBaseName(self)
            result=self.FileBaseName_;
        end
        
        function set.NextSweepIndex(self, newValue)
            if ws.isASettableValue(newValue), 
                if isnumeric(newValue) && isreal(newValue) && isscalar(newValue) && (newValue==round(newValue)) && newValue>=0 ,
                    newValue=double(newValue) ;
                    self.NextSweepIndex_ = newValue;
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'NextSweepIndex must be a (scalar) nonnegative integer');
                end
            end
            self.broadcast('Update');            
        end
        
        function result=get.NextSweepIndex(self)
            result=self.NextSweepIndex_;
        end

%         function result=get.CurrentSweepIndex(self)
%             result=self.CurrentSweepIndex_;
%         end

        function set.IsOKToOverwrite(self, newValue)
            if ws.isASettableValue(newValue), 
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && isfinite(newValue))) ,
                    self.IsOKToOverwrite_ = logical(newValue);
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'IsOKToOverwrite must be a logical scalar, or convertable to one');                  
                end
            end
            self.broadcast('Update');                        
        end
        
        function result=get.IsOKToOverwrite(self)
            result=self.IsOKToOverwrite_;
        end
        
        function set.DoIncludeDate(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && ~isnan(newValue))) ,
                    self.DoIncludeDate_ = logical(newValue);
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
                          'DoIncludeDate must be a logical scalar, or convertable to one');                  
                end
            end
            self.broadcast('Update');            
        end
        
        function result=get.DoIncludeDate(self)
            result=self.DoIncludeDate_;
        end

        function set.DoIncludeSessionIndex(self, newValue)
            if ws.isASettableValue(newValue) ,
                if isscalar(newValue) && (islogical(newValue) || (isnumeric(newValue) && ~isnan(newValue))) ,
                    originalValue = self.DoIncludeSessionIndex_ ;
                    newValueForReals = logical(newValue) ;
                    self.DoIncludeSessionIndex_ = newValueForReals ;
                    if newValueForReals && ~originalValue ,
                        self.NextSweepIndex_ = 1 ;
                        %self.FirstSweepIndexInNextFile_ = 1 ;
                    end
                else
                    self.broadcast('UpdateDoIncludeSessionIndex');
                    error('ws:invalidPropertyValue', ...
                          'DoIncludeSessionIndex must be a logical scalar, or convertable to one');                  
                end
            end
            self.broadcast('UpdateDoIncludeSessionIndex');            
        end
        
        function result=get.DoIncludeSessionIndex(self)
            result=self.DoIncludeSessionIndex_;
        end

        function set.SessionIndex(self, newValue)
            if ws.isASettableValue(newValue) ,
                if self.DoIncludeSessionIndex ,
                    if isnumeric(newValue) && isscalar(newValue) && round(newValue)==newValue && newValue>=1 ,
                        originalValue = self.SessionIndex_ ;
                        self.SessionIndex_ = newValue;
                        if newValue ~= originalValue ,
                            self.NextSweepIndex_ = 1 ;
                            %self.FirstSweepIndexInNextFile_ = 1 ;
                        end
                    else
                        self.broadcast('Update');
                        error('ws:invalidPropertyValue', ...
                              'SessionIndex must be an integer greater than or equal to one');
                    end
                else
                    self.broadcast('Update');
                    error('ws:invalidPropertyValue', ...
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
        
        function value=get.NextRunAbsoluteFileName(self)
            wavesurferModel=self.Parent;
            firstSweepIndex = self.NextSweepIndex ;
            numberOfSweeps = wavesurferModel.NSweepsPerRun ;
            fileName = self.sweepSetFileNameFromNumbers_(firstSweepIndex,numberOfSweeps);
            value = fullfile(self.FileLocation, fileName);
        end  % function
        
        function value=get.CurrentRunAbsoluteFileName(self)
            value = self.CurrentRunAbsoluteFileName_ ;
        end  % function
        
        function startingRun(self)
            if isempty(self.FileBaseName) ,
                error('wavesurfer:saveddatasystem:emptyfilename', 'Data logging can not be enabled with an empty filename.');
            end
            
            wavesurferModel = self.Parent ;
            
            % Note that we have not yet created the current data file
            self.DidCreateCurrentDataFile_ = false ;
            %fprintf('Just did self.DidCreateCurrentDataFile_ = false\n') ;
            
            % Set the chunk size for writing data to disk
            nActiveAnalogChannels = sum(wavesurferModel.Acquisition.IsAnalogChannelActive) ;
            
            % For h5create() it is useful to set
            % ExpectedSweepSizeForWritingHDF5_ = [Inf nActiveAnalogChannels] since
            % that enables proper writing of data from an aborted sweep
            % (otherwise, all values are set to 0 from when the sweep is aborted up to
            % wavesurferModel.Acquisition.SampleRate * wavesurferModel.Acquisiton.Duration)
            self.ExpectedSweepSizeForWritingHDF5_ = [Inf nActiveAnalogChannels];
            if wavesurferModel.AreSweepsFiniteDuration ,
                self.ChunkSize_ = [wavesurferModel.Acquisition.ExpectedScanCount nActiveAnalogChannels];
            else
                self.ChunkSize_ = [wavesurferModel.Acquisition.SampleRate nActiveAnalogChannels];
            end
                
            % Determine the absolute file names
            %self.CurrentRunAbsoluteFileName_ = fullfile(self.FileLocation, [trueLogFileName '.h5']);
            self.CurrentRunAbsoluteFileName_ = self.NextRunAbsoluteFileName ;
            %self.CurrentSweepIndex_ = self.NextSweepIndex ;
            
            % Store the first sweep index for the run 
            self.FirstSweepIndex_ = self.NextSweepIndex ;
            
            % If the target dir doesn't exist, create it
            if ~exist(self.FileLocation, 'dir')
                mkdir(self.FileLocation);
            end
            
            % Check for filename collisions, if that's what user wants
            if self.IsOKToOverwrite ,
                % don't need to check anything
                % But need to delete pre-existing files, otherwise h5create
                % will just add datasets to a pre-existing file.
                if exist(self.CurrentRunAbsoluteFileName_, 'file') == 2 ,
                    ws.deleteFileWithoutWarning(self.CurrentRunAbsoluteFileName_);
                end
%                 if exist(sidecarFileNameAbsolute, 'file') == 2 ,
%                     ws.deleteFileWithoutWarning(sidecarFileNameAbsolute);
%                 end
            else
                % Check if the log file already exists, and error if so
                if exist(self.CurrentRunAbsoluteFileName_, 'file') == 2 ,
                    error('wavesurfer:logFileAlreadyExists', ...
                          'The data file %s already exists', self.CurrentRunAbsoluteFileName_);
                end
%                 if exist(sidecarFileNameAbsolute, 'file') == 2 ,
%                     error('wavesurfer:sidecarFileAlreadyExists', ...
%                           'The sidecar file %s already exists', self.CurrentRunAbsoluteFileName_);
%                 end
            end

            % Extract all the "headerable" info in the WS model into a
            % structure
            headerStruct = wavesurferModel.encodeForHeader();
            
            % Put the header into into the log file header
            %numericPrecision=4;
            %stringOfAssignmentStatements= ws.most.util.structOrObj2Assignments(headerStruct, 'header', [], numericPrecision);
            doCreateFile=true;
            %ws.h5savestr(self.CurrentRunAbsoluteFileName_, '/headerstr', stringOfAssignmentStatements, doCreateFile);
            ws.h5save(self.CurrentRunAbsoluteFileName_, '/header', headerStruct, doCreateFile);
            self.DidCreateCurrentDataFile_ = true ;
            %fprintf('Just did self.DidCreateCurrentDataFile_ = true\n') ;
            
%             % Save the "header" information to a sidecar file instead.
%             % This should be more flexible that embedding the "header" data
%             % in with the data sensu strictu.
%             save('-mat',sidecarFileNameAbsolute,'-struct','headerStruct');
            
            % Set the write-to sweep ID so it's correct when data needs to
            % be written
            self.WriteToSweepId_ = self.NextSweepIndex;
            
            % Add an HDF "dataset" for each active AI channel, for each
            % sweep.
            % TODO: Try moving the dataset creation for each sweep to
            % startingSweep() --- This is the cause of slowness at sweep
            % set start for Justin Little, possibly others.
%             if ~isempty(wavesurferModel.Acquisition) ,
%                 for indexOfSweepWithinSet = 1:wavesurferModel.NSweepsPerRun ,
%                     h5create(self.CurrentRunAbsoluteFileName_, ...
%                              sprintf('/sweep_%04d', ...
%                                      self.WriteToSweepId_ + (indexOfSweepWithinSet-1)), ...
%                              self.ExpectedSweepSizeActual_, ...
%                              'ChunkSize', chunkSize, ...
%                              'DataType','int16');
%                 end
%             end
            
            % The next incoming scan will be written to this (one-based)
            % index in the dataset
            self.CurrentDatasetOffset_ = 1;
            
            % This should be empty until we create a dataset for a sweep
            self.LastSweepIndexForWhichDatasetCreated_ = [] ;
            
            % For tidyness
            self.DidWriteSomeDataForThisSweep_ = [] ;
        end
        
        function startingSweep(self)
            %profile resume
            % No data written at the start of the sweep
            self.DidWriteSomeDataForThisSweep_ = false ;
            %profile off
        end
        
        function completingSweep(self)
            self.NextSweepIndex = self.NextSweepIndex + 1;
        end
        
        function stoppingSweep(self)
            self.stoppingOrAbortingSweep_() ;
        end
        
        function abortingSweep(self)
            self.stoppingOrAbortingSweep_() ;
        end
        
        function completingRun(self)
            self.nullOutTransients_();
        end
        
        function stoppingRun(self)
            self.stoppingOrAbortingRun_();
        end
        
        function abortingRun(self)
            self.stoppingOrAbortingRun_();
        end        
    end  % public methods block
    
    methods (Access=protected)
        function stoppingOrAbortingSweep_(self)
            if isempty(self.LastSweepIndexForWhichDatasetCreated_) ,
                if isempty(self.FirstSweepIndex_) ,
                    % This probably means there was some sort of error
                    % before the sweep even started.  So just leave
                    % NextSweepIndex alone.
                else
                    % In this case, no datasets were created, so put the
                    % sweep index to the FirstSweepIndex for the set
                    self.NextSweepIndex = self.FirstSweepIndex_ ;
                end
            else
                self.NextSweepIndex = self.LastSweepIndexForWhichDatasetCreated_ + 1;
            end
        end
        
        function stoppingOrAbortingRun_(self)
            %fprintf('Logging::stoppingOrAbortingRun_()\n');
        
            %dbstop if caught
            %
            % Want to rename the data file to reflect the actual number of sweeps acquired
            %            
            if self.DidCreateCurrentDataFile_ ,
                %fprintf('self.DidCreateCurrentDataFile_ is true\n') ;
                % A data file was created.  Might need to rename it, or delete it.
                originalAbsoluteLogFileName = self.CurrentRunAbsoluteFileName_ ;
                originalLogFileName = ws.leafFileName(originalAbsoluteLogFileName) ;  % might need later, and cheap to compute
                firstSweepIndex = self.FirstSweepIndex_ ;
                if isempty(self.LastSweepIndexForWhichDatasetCreated_) ,
                    % This means no sweeps were actually added to the log file.
                    numberOfPartialSweepsLogged = 0 ;
                else                    
                    numberOfPartialSweepsLogged = self.LastSweepIndexForWhichDatasetCreated_ - firstSweepIndex + 1 ;  % includes complete and partial sweeps
                end
                if numberOfPartialSweepsLogged == 0 ,
                    % If no sweeps logged, and we actually created the data file for the current run, delete the file
                    try
                        ws.deleteFileWithoutWarning(originalAbsoluteLogFileName) ;
                    catch exception ,
                        self.logWarning('ws:unableToDeleteLogFile', ...
                                        sprintf('Unable to delete data file %s after stop/abort', ...
                                                originalLogFileName), ...
                                        exception) ;                            
                    end
                else    
                    % We logged some sweeps, but maybe not the number requested.  Check for this, renaming the
                    % data file if needed.
                    newLogFileName = self.sweepSetFileNameFromNumbers_(firstSweepIndex,numberOfPartialSweepsLogged) ;
                    newAbsoluteLogFileName = fullfile(self.FileLocation, newLogFileName);
                    if isequal(originalAbsoluteLogFileName,newAbsoluteLogFileName) ,
                        % Nothing to do in this case.
                        % This case might happen, e.g. if the number of sweeps is inf
                        % do nothing.
                    else
                        isSafeToMoveFile = false ;
                        % Check for filename collisions, if that's what user wants
                        if exist(newAbsoluteLogFileName, 'file') == 2 ,
                            if self.IsOKToOverwrite ,
                                % Don't need to check anything.
                                % But need to delete pre-existing files, otherwise h5create
                                % will just add datasets to a pre-existing file.
                                try
                                    ws.deleteFileWithoutWarning(newAbsoluteLogFileName) ;
                                    isSafeToMoveFile = true ;
                                catch exception ,
                                    self.logWarning('ws:unableToRenameLogFile', ...
                                                    sprintf(horzcat('Unable to rename data file %s to %s after stop/abort, ', ...
                                                                    'because couldn''t delete pre-existing file %s'), ...
                                                            originalLogFileName, ...
                                                            newLogFileName, ...
                                                            newLogFileName), ...
                                                    exception) ;
                                end
                            else
                                % This means there's a filename collision,
                                % and user doesn't want us to overwrite
                                % files without asking.
                                isSafeToMoveFile = false ; 
                                self.logWarning('ws:unableToRenameLogFile', ...
                                                sprintf('Unable to rename data file %s to %s after stop/abort, because file %s already exists', ...
                                                        originalLogFileName, ...
                                                        newLogFileName, ...
                                                        newLogFileName) ) ;
                            end
                        else
                            % Target file doesn't exist, so safe to move
                            isSafeToMoveFile = true ;
                        end
                        % If all is well here, rename the file
                        if isSafeToMoveFile ,
                            try
                                movefile(originalAbsoluteLogFileName, newAbsoluteLogFileName) ;
                            catch exception ,
                                self.logWarning('ws:unableToRenameLogFile', ...
                                                sprintf('Unable to rename data file %s to %s after stop/abort', ...
                                                        originalLogFileName, ...
                                                        newLogFileName), ...
                                                exception) ;
                            end                                
                        end                
                    end
                end
            else
                % No data file was created, so nothing to do.
                %fprintf('self.DidCreateCurrentDataFile_ is false\n') ;
            end

            % Now do things common to performance and abortion
            self.nullOutTransients_();

%             % Now throw that exception, if there was one
%             %dbclear all
%             if isempty(exception) ,                
%                 % do nothing
%             else
%                 throw(exception);
%             end            
        end  % function
            
        function nullOutTransients_(self)
            % null-out all the transient things that are only used during
            % the run
            self.CurrentRunAbsoluteFileName_ = [];
            self.FirstSweepIndex_ = [] ;
            self.CurrentDatasetOffset_ = [];
  %          self.ExpectedSweepSizeActual_ = [];
            self.ExpectedSweepSizeForWritingHDF5_ = [];
            self.WriteToSweepId_ = [];
            self.ChunkSize_ = [];
            self.DidCreateCurrentDataFile_ = [] ;
            self.LastSweepIndexForWhichDatasetCreated_ = [] ;
            self.DidWriteSomeDataForThisSweep_ = [] ;
            %self.CurrentSweepIndex_ = [];
        end  % function
    end

    methods
        function dataAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSL>
            %ticId=tic();
            
%             if self.Parent.State == ws.ApplicationState.TestPulsing || self.CurrentDatasetOffset_ < 1
%                 return
%             end
            
            %dataSingle=single(scaledData);
            %inputChannelNames=self.Parent.Acquisition.ActiveChannelNames;
            %nActiveChannels=self.Parent.Acquisition.NActiveChannels;
            if ~self.DidWriteSomeDataForThisSweep_ ,
                % Moved creation of h5 Group "sweep_%04d" from
                % startingSweep() to here, preventing a sweep Group from
                % being created until it has data.
                thisSweepIndex = self.NextSweepIndex ;
                timestampDatasetName = sprintf('/sweep_%04d/timestamp',thisSweepIndex) ;
                h5create(self.CurrentRunAbsoluteFileName_, timestampDatasetName, [1 1]);  % will consist of one double
                nActiveAnalogChannels = self.Parent.Acquisition.NActiveAnalogChannels ;
                if nActiveAnalogChannels>0 ,
                    analogScansDatasetName = sprintf('/sweep_%04d/analogScans',thisSweepIndex) ;
                    h5create(self.CurrentRunAbsoluteFileName_, ...
                        analogScansDatasetName, ...
                        self.ExpectedSweepSizeForWritingHDF5_, ...
                        'ChunkSize', self.ChunkSize_, ...
                        'DataType','int16');
                end
                nActiveDigitalChannels = self.Parent.Acquisition.NActiveDigitalChannels ;
                if nActiveDigitalChannels>0 ,
                    if nActiveDigitalChannels<=8
                        dataType = 'uint8';
                    elseif nActiveDigitalChannels<=16
                        dataType = 'uint16';
                    else %NActiveDigitalChannels<=32
                        dataType = 'uint32';
                    end
                    digitalScansDatasetName = sprintf('/sweep_%04d/digitalScans',thisSweepIndex) ;
                    h5create(self.CurrentRunAbsoluteFileName_, ...
                        digitalScansDatasetName, ...
                        [self.ExpectedSweepSizeForWritingHDF5_(1) 1], ...
                        'ChunkSize', [self.ChunkSize_(1) 1], ...
                        'DataType',dataType);
                end
                self.LastSweepIndexForWhichDatasetCreated_ =  thisSweepIndex;           
                
                timestampDatasetName = sprintf('/sweep_%04d/timestamp',self.WriteToSweepId_) ;
                h5write(self.CurrentRunAbsoluteFileName_, timestampDatasetName, timeSinceRunStartAtStartOfData);
                self.DidWriteSomeDataForThisSweep_ = true ;  % will be true momentarily...
            end
            
            if ~isempty(self.FileBaseName) ,
                if ~isempty(rawAnalogData) ,
                    h5write(self.CurrentRunAbsoluteFileName_, ...
                            sprintf('/sweep_%04d/analogScans', ...
                                    self.WriteToSweepId_), ...
                            rawAnalogData, ...
                            [self.CurrentDatasetOffset_ 1], ...
                            size(rawAnalogData));
                end
                if ~isempty(rawDigitalData) ,
                    h5write(self.CurrentRunAbsoluteFileName_, ...
                            sprintf('/sweep_%04d/digitalScans', ...
                                    self.WriteToSweepId_), ...
                            rawDigitalData, ...
                            [self.CurrentDatasetOffset_ 1], ...
                            size(rawDigitalData));
                end
            end
            
            self.CurrentDatasetOffset_ = self.CurrentDatasetOffset_ + size(scaledAnalogData, 1);
            
            wavesurferModel = self.Parent ;
            if self.CurrentDatasetOffset_ > wavesurferModel.Acquisition.ExpectedScanCount ,
                self.CurrentDatasetOffset_ = 1;
                self.WriteToSweepId_ = self.WriteToSweepId_ + 1;
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
        
        function fileName = sweepSetFileNameFromNumbers_(self,firstSweepIndex,numberOfSweeps)
            augmentedBaseName = self.augmentedBaseName_() ;
            % This is a "leaf" file name, not an absolute one
            if numberOfSweeps == 1 ,
                fileName = sprintf('%s_%04d.h5', augmentedBaseName, firstSweepIndex);
            else
                if isfinite(numberOfSweeps) ,
                    lastSweepIndex = firstSweepIndex + numberOfSweeps - 1 ;
                    fileName = sprintf('%s_%04d-%04d.h5', ...
                                       augmentedBaseName, ...
                                       firstSweepIndex, ...
                                       lastSweepIndex);
                else
                    fileName = sprintf('%s_%04d-.h5', ...
                                       augmentedBaseName, ...
                                       firstSweepIndex);
                end
            end            
        end  % function        
    end  % static methods block
    
    methods (Access = protected)
%         function defineDefaultPropertyAttributes(self)
%             defineDefaultPropertyAttributes@ws.Subsystem(self);
%             self.setPropertyAttributeFeatures('FileLocation', 'Classes', 'char', 'Attributes', {'vector'});
%             self.setPropertyAttributeFeatures('FileBaseName', 'Classes', 'char', 'Attributes', {'vector'});
%             self.setPropertyAttributeFeatures('NextSweepIndex', 'Attributes', {'scalar', 'finite', 'integer', '>=', 1});
%         end
        
%         function defineDefaultPropertyTags_(self)
%             defineDefaultPropertyTags_@ws.Subsystem(self);            
%             % self.setPropertyTags('Enabled', 'ExcludeFromFileTypes', {'*'});  
%             %self.setPropertyTags('Enabled', 'IncludeInFileTypes', {'cfg'});
%             %self.setPropertyTags('Enabled', 'ExcludeFromFileTypes', {'usr'});            
%             self.setPropertyTags('FileLocation', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('FileBaseName', 'IncludeInFileTypes', {'cfg'});
%             self.setPropertyTags('NextSweepIndex', 'IncludeInFileTypes', {'cfg'});
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
%                 self.NextSweepIndex = 1;
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
%             self.IsEnabled=true;
%             self.FileBaseName='untitled';
%             self.FileLocation='C:\Data';
%             self.NextSweepIndex=1;
%         end  % function
%     end % methods

    methods (Access=protected)        
        function out = getPropertyValue_(self, name)
            out = self.(name);
        end  % function
        
        % Allows access to protected and protected variables from ws.Coding.
        function setPropertyValue_(self, name, value)
            self.(name) = value;
        end  % function
    end
    
%     properties (Hidden, SetAccess=protected)
%         mdlPropAttributes = struct();        
%         mdlHeaderExcludeProps = {};
%     end        
    
end
