classdef Logging < ws.system.Subsystem
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

    properties (Access = protected, Transient = true)
        DateAsString_
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
    
    % These are all properties that are only used when acquisition is
    % ongoing.  They are set in willPerformRun(), and are nulled in
    % didCompleteRun() and didAbortRun()
    properties (Access = protected, Transient=true)
        CurrentRunAbsoluteFileName_
        CurrentDatasetOffset_
            % during acquisition, the index of the next "scan" to be written (one-based)
            % "scan" is an NI-ism meaning all the samples acquired for a
            % single time stamp
        ExpectedSweepSize_  
            % if all the acquired data for one sweep were put into an array, this
            % would be the size of that array.  
            % I.e. [nScans nActiveChannels]        
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
            self.Parent=parent;
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
        
        function delete(self)
            self.Parent=[];
        end
        
        function set.FileLocation(self, newValue)
            if ws.utility.isASettableValue(newValue), 
                self.validatePropArg('FileLocation', newValue);
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
                % If file name has changed, reset the sweep index
                originalFullName=fullfile(self.FileLocation,originalValue);
                newFullName=fullfile(self.FileLocation,newValue);
                if ~isequal(originalFullName,newFullName) ,
                    %fprintf('About to reset NextSweepIndex...\n');
                    self.NextSweepIndex = 1;
                end
            end
            %self.broadcast('DidSetFileBaseName');            
            self.broadcast('Update');            
        end
        
        function result=get.FileBaseName(self)
            result=self.FileBaseName_;
        end
        
        function set.NextSweepIndex(self, newValue)
            %fprintf('set.NextSweepIndex\n');
            %dbstack
            if ws.utility.isASettableValue(newValue), 
                self.validatePropArg('NextSweepIndex', newValue);
                self.NextSweepIndex_ = newValue;
                %self.FirstSweepIndexInNextFile_ = newValue_ ;
            end
            %self.broadcast('DidSetNextSweepIndex');            
            self.broadcast('Update');            
        end
        
        function result=get.NextSweepIndex(self)
            result=self.NextSweepIndex_;
        end

%         function result=get.CurrentSweepIndex(self)
%             result=self.CurrentSweepIndex_;
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
                        self.NextSweepIndex_ = 1 ;
                        %self.FirstSweepIndexInNextFile_ = 1 ;
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
                            self.NextSweepIndex_ = 1 ;
                            %self.FirstSweepIndexInNextFile_ = 1 ;
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
        
        function willPerformRun(self)
            if isempty(self.FileBaseName) ,
                error('wavesurfer:saveddatasystem:emptyfilename', 'Data logging can not be enabled with an empty filename.');
            end
            
            wavesurferModel = self.Parent ;
            
            % Note that we have not yet created the current data file
            self.DidCreateCurrentDataFile_ = false ;
            
            % Set the chunk size for writing data to disk
            nActiveAnalogChannels = sum(wavesurferModel.Acquisition.IsAnalogChannelActive) ;
            if wavesurferModel.AreSweepsFiniteDuration ,
                self.ExpectedSweepSize_ = [wavesurferModel.Acquisition.ExpectedScanCount nActiveAnalogChannels];
                if any(isinf(self.ExpectedSweepSize_))
                    self.ChunkSize_ = [wavesurferModel.Acquisition.SampleRate nActiveAnalogChannels];
                else
                    self.ChunkSize_ = self.ExpectedSweepSize_;
                end
            else
                self.ExpectedSweepSize_ = [Inf nActiveAnalogChannels];
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
                    ws.utility.deleteFileWithoutWarning(self.CurrentRunAbsoluteFileName_);
                end
%                 if exist(sidecarFileNameAbsolute, 'file') == 2 ,
%                     ws.utility.deleteFileWithoutWarning(sidecarFileNameAbsolute);
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
            headerStruct = wavesurferModel.encodeForFileType('header');
            
            % Put the header into into the log file header
            %numericPrecision=4;
            %stringOfAssignmentStatements= ws.most.util.structOrObj2Assignments(headerStruct, 'header', [], numericPrecision);
            doCreateFile=true;
            %ws.most.fileutil.h5savestr(self.CurrentRunAbsoluteFileName_, '/headerstr', stringOfAssignmentStatements, doCreateFile);
            ws.most.fileutil.h5save(self.CurrentRunAbsoluteFileName_, '/header', headerStruct, doCreateFile);
            self.DidCreateCurrentDataFile_ = true ;
            
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
            % willPerformSweep() --- This is the cause of slowness at sweep
            % set start for Justin Little, possibly others.
%             if ~isempty(wavesurferModel.Acquisition) ,
%                 for indexOfSweepWithinSet = 1:wavesurferModel.NSweepsPerRun ,
%                     h5create(self.CurrentRunAbsoluteFileName_, ...
%                              sprintf('/sweep_%04d', ...
%                                      self.WriteToSweepId_ + (indexOfSweepWithinSet-1)), ...
%                              self.ExpectedSweepSize_, ...
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
        
        function willPerformSweep(self)
            %profile resume
            thisSweepIndex = self.NextSweepIndex ;
            timestampDatasetName = sprintf('/sweep_%04d/timestamp',thisSweepIndex) ;
            h5create(self.CurrentRunAbsoluteFileName_, timestampDatasetName, [1 1]);  % will consist of one double
            scansDatasetName = sprintf('/sweep_%04d/analogScans',thisSweepIndex) ;
            h5create(self.CurrentRunAbsoluteFileName_, ...
                     scansDatasetName, ...
                     self.ExpectedSweepSize_, ...
                     'ChunkSize', self.ChunkSize_, ...
                     'DataType','int16');
            scansDatasetName = sprintf('/sweep_%04d/digitalScans',thisSweepIndex) ;
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
                h5create(self.CurrentRunAbsoluteFileName_, ...
                         scansDatasetName, ...
                         [self.ExpectedSweepSize_(1) 1], ...
                         'ChunkSize', [self.ChunkSize_(1) 1], ...
                         'DataType',dataType);
            end
            self.LastSweepIndexForWhichDatasetCreated_ =  thisSweepIndex;                     
            self.DidWriteSomeDataForThisSweep_ = false ;
            %profile off
        end
        
        function didCompleteSweep(self)
            %if wavesurferModel.State == ws.ApplicationState.AcquiringSweepBased ,
                %self.CurrentSweepIndex_ = self.CurrentSweepIndex_ + 1 ;
                self.NextSweepIndex = self.NextSweepIndex + 1;
            %end
        end
        
        function didAbortSweep(self)
            %if wavesurferModel.State == ws.ApplicationState.AcquiringSweepBased ,
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
            %end
        end
        
        function didCompleteRun(self)
            self.didPerformOrAbortRun_();
        end
        
        function didAbortRun(self)
            %fprintf('Logging::didAbortRun()\n');
        
            %dbstop if caught
            %
            % Want to rename the data file to reflect the actual number of sweeps acquired
            %
            exception = [] ;
            if self.DidCreateCurrentDataFile_ ,
                % A data file was created.  Might need to rename it, or delete it.
                originalAbsoluteLogFileName = self.CurrentRunAbsoluteFileName_ ;
                firstSweepIndex = self.FirstSweepIndex_ ;
                if isempty(self.LastSweepIndexForWhichDatasetCreated_) ,
                    % This means no sweeps were actually added to the log file.
                    numberOfPartialSweepsLogged = 0 ;
                else                    
                    numberOfPartialSweepsLogged = self.LastSweepIndexForWhichDatasetCreated_ - firstSweepIndex + 1 ;  % includes complete and partial sweeps
                end
                if numberOfPartialSweepsLogged == 0 ,
                    % If no sweeps logged, and we actually created the data file for the current run, delete the file
                    if self.DidCreateCurrentDataFile_ ,
                        ws.utility.deleteFileWithoutWarning(originalAbsoluteLogFileName);
                    else
                        % nothing to do
                    end
                else    
                    % We logged some sweeps, but maybe not the number number requested.  Check for this, renaming the
                    % data file if needed.
                    newLogFileName = self.sweepSetFileNameFromNumbers_(firstSweepIndex,numberOfPartialSweepsLogged) ;
                    newAbsoluteLogFileName = fullfile(self.FileLocation, newLogFileName);
                    if isequal(originalAbsoluteLogFileName,newAbsoluteLogFileName) ,
                        % This might happen, e.g. if the number of sweeps is inf
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
            self.didPerformOrAbortRun_();

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
%         function didPerformOrAbortSweep_(self, wavesurferModel)
%             if wavesurferModel.State == ws.ApplicationState.AcquiringSweepBased ,
%                 self.NextSweepIndex = self.NextSweepIndex + 1;
%             end
%         end
        
        function didPerformOrAbortRun_(self)
            % null-out all the transient things that are only used during
            % the run
            self.CurrentRunAbsoluteFileName_ = [];
            self.FirstSweepIndex_ = [] ;
            self.CurrentDatasetOffset_ = [];
            self.ExpectedSweepSize_ = [];
            self.WriteToSweepId_ = [];
            self.ChunkSize_ = [];
            self.DidCreateCurrentDataFile_ = [] ;
            self.LastSweepIndexForWhichDatasetCreated_ = [] ;
            self.DidWriteSomeDataForThisSweep_ = [] ;
            %self.CurrentSweepIndex_ = [];
        end
    end

    methods
        function dataIsAvailable(self, isSweepBased, t, scaledAnalogData, rawAnalogData, rawDigitalData, timeSinceRunStartAtStartOfData) %#ok<INUSL>
            %ticId=tic();
            
%             if self.Parent.State == ws.ApplicationState.TestPulsing || self.CurrentDatasetOffset_ < 1
%                 return
%             end
            
            %dataSingle=single(scaledData);
            %inputChannelNames=self.Parent.Acquisition.ActiveChannelNames;
            %nActiveChannels=self.Parent.Acquisition.NActiveChannels;
            if ~self.DidWriteSomeDataForThisSweep_ ,
                timestampDatasetName = sprintf('/sweep_%04d/timestamp',self.WriteToSweepId_) ;
                h5write(self.CurrentRunAbsoluteFileName_, timestampDatasetName, timeSinceRunStartAtStartOfData);
                self.DidWriteSomeDataForThisSweep_ = true ;  % will be true momentarily...
            end
            
            if ~isempty(self.FileBaseName) ,
                h5write(self.CurrentRunAbsoluteFileName_, ...
                        sprintf('/sweep_%04d/analogScans', ...
                                self.WriteToSweepId_), ...
                                rawAnalogData, ...
                                [self.CurrentDatasetOffset_ 1], ...
                                size(rawAnalogData));
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
            
            if self.CurrentDatasetOffset_ > self.ExpectedSweepSize_(1) ,
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
%             defineDefaultPropertyAttributes@ws.system.Subsystem(self);
%             self.setPropertyAttributeFeatures('FileLocation', 'Classes', 'char', 'Attributes', {'vector'});
%             self.setPropertyAttributeFeatures('FileBaseName', 'Classes', 'char', 'Attributes', {'vector'});
%             self.setPropertyAttributeFeatures('NextSweepIndex', 'Attributes', {'scalar', 'finite', 'integer', '>=', 1});
%         end
        
%         function defineDefaultPropertyTags(self)
%             defineDefaultPropertyTags@ws.system.Subsystem(self);            
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
            s = struct();
            s.FileLocation = struct('Classes', 'string');
            s.FileBaseName = struct('Classes', 'string');
            s.NextSweepIndex = struct('Attributes', {{'scalar', 'finite', 'integer', '>=', 1}});
            s.IsOKToOverwrite = struct('Classes','binarylogical', 'Attributes', {{'scalar'}} );            
        end  % function
    end  % class methods block
    
    
end
